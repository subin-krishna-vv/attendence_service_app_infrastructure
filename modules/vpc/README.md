# vpc

Creates one region's network: a `/16` VPC with **3 public and 3 private `/20` subnets** (one of each per AZ), an internet gateway, **one regional NAT gateway** for outbound traffic from the private subnets, and **S3 and DynamoDB gateway endpoints**.

## Resources

Counts and CIDRs shown are for the defaults (`az_count = 3`, `subnet_newbits = 4`, offsets 0 and 8); each can be overridden (see Inputs).

| Resource | Count | Purpose |
| --- | --- | --- |
| `aws_vpc.this` | 1 | DNS support and hostnames on |
| `aws_default_security_group.this` | 1 | Takes over the default SG and removes all its rules, so nothing can use it by accident |
| `aws_internet_gateway.this` | 1 | Internet access for the public subnets |
| `aws_subnet.public` | 3 | ALB. Keyed by AZ name; no auto-assigned public IPs |
| `aws_subnet.private` | 3 | ECS tasks, DAX. Keyed by AZ name |
| `aws_route_table.public` + `aws_route.public_internet` | 1 + 1 | `0.0.0.0/0` → internet gateway |
| `aws_route_table.private` + `aws_route.private_nat` | 1 + 0/1 | `0.0.0.0/0` → regional NAT gateway |
| `aws_route_table_association.*` | 6 | One per subnet |
| `aws_nat_gateway.this` | 0/1 | **Regional** (`availability_mode = "regional"`), auto mode |
| `aws_vpc_endpoint.s3` | 0/1 | S3 gateway endpoint on the private route table |
| `aws_vpc_endpoint.dynamodb` | 0/1 | DynamoDB gateway endpoint on the private route table |

## Subnet layout

Subnets are computed from `vpc_cidr` with `cidrsubnet(vpc_cidr, 4, n)`, so the offsets are the same in every `/16`:

| Tier | AZ a | AZ b | AZ c | Free for growth |
| --- | --- | --- | --- | --- |
| Public (`n` = 0–2) | `10.10.0.0/20` | `10.10.16.0/20` | `10.10.32.0/20` | `10.10.48.0` – `10.10.127.255` |
| Private (`n` = 8–10) | `10.10.128.0/20` | `10.10.144.0/20` | `10.10.160.0/20` | `10.10.176.0` – `10.10.255.255` |

Each `/20` has 4,091 usable IPs. Every Fargate task uses one IP.

**AZ selection:** the module uses the first 3 standard AZs sorted by name. It queries every state and filters on `opt-in-status = opt-in-not-required` to leave out Local and Wavelength Zones. Not filtering on state means an AZ marked *impaired* during an outage does not shift the list, which would otherwise make Terraform plan to replace subnets.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name_prefix` | string | — (required) | Prefix for resource Name tags: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1. |
| `vpc_cidr` | string | — (required) | VPC CIDR block. Must be a /16 that does not overlap any other environment or region (see README CIDR plan). |
| `enable_nat_gateway` | bool | `true` | Create the regional NAT gateway and the private subnets' default route through it. |
| `enable_s3_endpoint` | bool | `true` | Create the S3 gateway endpoint on the private route table. |
| `enable_dynamodb_endpoint` | bool | `true` | Create the DynamoDB gateway endpoint on the private route table. |
| `az_count` | number | `3` | Number of Availability Zones (first N standard AZs by name); one public and one private subnet per AZ. |
| `subnet_newbits` | number | `4` | Bits added to the VPC prefix for each subnet (4 on a /16 gives /20 subnets). |
| `public_subnet_offset` | number | `0` | cidrsubnet index of the first public subnet; public subnets take az_count consecutive indexes from here. |
| `private_subnet_offset` | number | `8` | cidrsubnet index of the first private subnet; private subnets take az_count consecutive indexes from here. |
| `enable_dns_support` | bool | `true` | Enable the Amazon-provided DNS resolver in the VPC (needed for gateway endpoints and private DNS). |
| `enable_dns_hostnames` | bool | `true` | Give instances and ENIs public/private DNS hostnames. |
| `map_public_ip_on_launch` | bool | `false` | Auto-assign public IPv4 addresses to ENIs launched in the subnets. Keep false: the ALB and NAT do not need it. |

## Outputs

| Name | Description |
| --- | --- |
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR |
| `azs` | The 3 AZ names, in subnet order |
| `public_subnet_ids` | Public subnet IDs (list, ordered as `azs`) |
| `private_subnet_ids` | Private subnet IDs (list, ordered as `azs`) |
| `public_route_table_id` | Public route table ID |
| `private_route_table_id` | Private route table ID |
| `nat_gateway_id` | Regional NAT gateway ID, or `null` when disabled |
| `internet_gateway_id` | Internet gateway ID |
| `s3_endpoint_id` | S3 gateway endpoint ID, or `null` when disabled |
| `dynamodb_endpoint_id` | DynamoDB gateway endpoint ID, or `null` when disabled |

## Toggles

| Toggle | Default | Effect when `false` |
| --- | --- | --- |
| `enable_nat_gateway` | `true` | No NAT gateway and no private default route. Private subnets can then reach only S3/DynamoDB (through the endpoints), and Docker Hub pulls fail. |
| `enable_s3_endpoint` | `true` | S3 traffic from private subnets goes through the NAT gateway instead (billed per GB) |
| `enable_dynamodb_endpoint` | `true` | DynamoDB traffic from private subnets goes through the NAT gateway instead (billed per GB) |

## Example

```hcl
module "vpc" {
  source      = "../../../modules/vpc"
  name_prefix = "attendance-service-dev-use1"
  vpc_cidr    = "10.10.0.0/16"
}
```

## Design notes

- **Why a regional NAT gateway instead of one NAT per AZ:**
  - It costs the same: billed per AZ-hour, so $0.045/h × 3 AZs in us-east-2.
  - It needs one resource and one private route table instead of 3 NATs, 3 EIPs and 3 route tables.
  - It stays highly available on its own by following workloads into each AZ.
  - The NAT doesn't need a public subnet.
- **Regional NAT caveats:**
  - It can take up to 60 minutes to expand into a newly used AZ. Until then, traffic goes through an existing AZ, so it still works but crosses AZs.
  - In auto mode AWS manages the outbound IPs, so they aren't fixed in advance. Any third party that allowlists our egress IPs would need manual mode.
  - It doesn't support private NAT, and isn't available in constrained AZs.
- **Gateway endpoints only.** S3 and DynamoDB gateway endpoints are free and keep that traffic off the NAT gateway. They use the AWS default (full access) endpoint policy; IAM on each role decides what callers may do. There are **no interface endpoints** (ECR, CloudWatch Logs) for now, so ECS log delivery and image pulls go through the NAT gateway.
- **No separate data subnets.** DAX runs in the private subnets and is isolated by its own security group (only the ECS task SG may reach it).
- **No VPC flow logs** (design decision; Checkov CKV2_AWS_11 is skipped).
- IPv4 only. The default NACL (allow all) is left as is; security groups are the control point.

## Cost (billed hourly)

- **Regional NAT gateway:** $0.045 per AZ-hour (us-east-2 pricing; check the us-east-1 rate on the AWS VPC pricing page). With 3 AZs that's about $0.135/h, or roughly $99/month per region and about $197/month for dev across both regions. Data processing is $0.045/GB on top.
- **Public IPv4:** $0.005/h per address used by the NAT gateway.
- **Gateway endpoints:** free.
