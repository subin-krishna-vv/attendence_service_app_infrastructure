# envs/dev/us-east-1

Regional stack for **dev in us-east-1**: the network, TLS certificate, ALB, WAF, ECS service and alarms. `envs/dev/us-east-2` is identical apart from its region defaults (`us-east-2`, `use2`, `10.11.0.0/16`) and its state key.

| Module | Creates |
| --- | --- |
| `vpc` | VPC `10.10.0.0/16`, 3 public + 3 private `/20` subnets, regional NAT, S3/DynamoDB gateway endpoints |
| `certificate` | ACM certificate for `dev.attendance.<base_domain>` + wildcard, DNS-validated in the env zone |
| `alb` | Internet-facing ALB, HTTPS listener, HTTP→HTTPS redirect, target group, access-log bucket |
| `waf` (`count` = `enable_waf`) | Web ACL with AWS managed rules (count mode) attached to the ALB, logs to CloudWatch |
| `ecs_service` | Fargate cluster and service running pinned nginx, autoscaling 3–6 tasks |
| `observability` | SNS alarm topic with email subscriptions, SLO and supporting alarms |

## Apply order (whole environment)

1. `bootstrap/dev`, once.
2. `envs/dev/global`, then add the NS delegation for `dev.attendance.<base_domain>` at your DNS provider.
3. **`envs/dev/us-east-1`**, then `envs/dev/us-east-2`.
4. `envs/dev/global-dns`.

## Configuration and private values

```sh
cp terraform.tfvars.example terraform.tfvars
```

- **`terraform.tfvars` is gitignored.** Put values that must not be committed there: `base_domain` and the real `alarm_emails`. The example lists every setting with its default.
- **Each email address must confirm** the subscription email from AWS before it receives alarms.
- **Settings not exposed as stack variables** keep their module defaults. Override them in the module block in `main.tf`. See each module's README for the full list of inputs.

## Usage

```sh
export AWS_PROFILE=<your-profile>
cd envs/dev/us-east-1
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Saved plan files (`tfplan`) are gitignored.

## Checks

```sh
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
tflint --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
```

## Outputs

| Name | Description |
| --- | --- |
| `name_prefix` | `attendance-service-dev-use1`; must match `regions` in `envs/dev/global-dns` |
| `vpc_id` | VPC ID |
| `certificate_arn` | Validated certificate ARN |
| `alb_dns_name` / `alb_zone_id` | Regional ALB endpoint |
| `alb_access_logs_bucket` | ALB access-log bucket |
| `web_acl_arn` | Web ACL ARN, or `null` when WAF is off |
| `ecs_cluster_name` / `ecs_service_name` | ECS names |
| `alarm_topic_arn` | SNS alarm topic (the us-east-1 topic also receives Route 53 health check alarms) |

## Notes

- **The certificate waits for DNS validation.** If the NS delegation isn't in place yet, apply waits up to 75 minutes on `module.certificate.aws_acm_certificate_validation.this`.
- **The ECS service waits for the ALB** (`depends_on = [module.alb]`). The target group must be attached to a listener before ECS can register tasks.
- **Destroying the stack takes extra steps:**
  1. Set `enable_alb_deletion_protection = false` and apply.
  2. Empty the ALB access-log bucket, including object versions, or set `log_bucket_force_destroy = true` on the `alb` module block.
  3. Destroy `envs/dev/global-dns` first, because it references this ALB.
- **Name length:** the ALB name `<name_prefix>-alb` must fit in 32 characters. `attendance-service-dev-use1` is 27, which fits.
