# Classroom Attendance Service — Infrastructure

Terraform for an AWS-hosted Classroom attendance service, running **active-active in two regions** (us-east-1 and us-east-2). The service itself is simulated by the **default nginx welcome page**.

## Service level objectives

| SLO | Target | Measured at |
| --- | --- | --- |
| Success rate | 99.99% of requests are not 5xx (≈ 4 min 19 s of failure per 30 days) | ALB: 1 − (`HTTPCode_ELB_5XX_Count` + `HTTPCode_Target_5XX_Count`) / `RequestCount` |
| Latency | 99.99% of responses complete in < 300 ms | ALB: `TargetResponseTime` p99.99 |

Both are request-based over a rolling 30 days. 4xx responses are excluded.

## Architecture

```text
                    Users
                      |
        Route 53 (latency routing + health checks)
              /                    \
       us-east-1                  us-east-2
     WAF -> ALB (HTTPS)        WAF -> ALB (HTTPS)
           |                         |
     ECS Fargate (nginx)       ECS Fargate (nginx)
     private subnets, 3 AZs    private subnets, 3 AZs

     CloudWatch alarms + one dashboard for both regions
```

- **Both regions serve traffic.** Route 53 sends users to the nearest healthy region and moves traffic away from a failing one.
- **Each region runs across 3 AZs.** ECS keeps 3–6 nginx tasks behind the ALB, with rolling deployments and automatic rollback.
- **The SLOs are measured at the ALB.** Alarms email the team, and one dashboard shows both regions.

### Stacks (apply in this order)

| # | Stack | Creates |
| --- | --- | --- |
| 1 | `bootstrap/<env>` | Terraform state bucket (once) |
| 2 | `envs/<env>/global` | DNS zone `<env>.attendance.<base_domain>` |
| 3 | `envs/<env>/us-east-1`, `envs/<env>/us-east-2` | Network, certificate, ALB, WAF, ECS, alarms |
| 4 | `envs/<env>/global-dns` | Latency DNS records, health checks, dashboard |

See [Deploy step by step](#deploy-step-by-step) for the exact commands.

### Network

Each region has its own VPC (dev: `10.10.0.0/16` in us-east-1, `10.11.0.0/16` in us-east-2). Each VPC has 3 public subnets (ALB) and 3 private subnets (ECS), one regional NAT gateway, and free S3/DynamoDB endpoints.

### On/off toggles

Optional parts can be turned off in each stack's `terraform.tfvars`, for example `enable_waf`, `enable_certificate`, `enable_dns_zone`, `enable_dns_records`, `enable_dashboard` and `enable_sns` (alarm emails). All default to `true`. See each stack's README for the full list.

### Not built yet

DynamoDB + DAX (data layer), smoke and load tests, and the staging/prod environments.

## Deploy step by step

These steps deploy the **dev** environment. Run every command from the repo root unless a step says otherwise.

### 1. Prerequisites

- Terraform `~> 1.16.1` (AWS provider `~> 6.68` is installed by `terraform init`).
- [tflint](https://github.com/terraform-linters/tflint) and Docker (for [checkov](https://www.checkov.io/)). Only needed for the checks.
- AWS credentials for the target account:

  ```sh
  export AWS_PROFILE=<your-profile>     # or log in with SSO
  ```

- A domain you control (`base_domain`, e.g. `example.com`), where you can add NS records at its DNS provider. If you have no domain, see [Run without a domain](#run-without-a-domain).

### 2. Create the tfvars files

```sh
for d in bootstrap/dev envs/dev/global envs/dev/us-east-1 envs/dev/us-east-2 envs/dev/global-dns; do
  cp "$d/terraform.tfvars.example" "$d/terraform.tfvars"
done
```

Edit them (they are gitignored):

| File | Set |
| --- | --- |
| `envs/dev/global/terraform.tfvars` | `base_domain` |
| `envs/dev/us-east-1/terraform.tfvars` | `base_domain`, `alarm_emails` (real addresses) |
| `envs/dev/us-east-2/terraform.tfvars` | `base_domain`, `alarm_emails` |
| `envs/dev/global-dns/terraform.tfvars` | `base_domain` |

If you change `company` (default `abc`), also change the backend `bucket` in every `envs/dev/*/versions.tf` to `attendance-service-dev-tfstate-<company>`.

### 3. State bucket (once)

```sh
cd bootstrap/dev
terraform init
terraform plan
terraform apply
cd -
```

### 4. DNS zone

```sh
cd envs/dev/global
terraform init
terraform apply
terraform output name_servers
cd -
```

At your domain's DNS provider, add an **NS record** for `dev.attendance` with the 4 name servers from the output. Check it before continuing:

```sh
dig NS dev.attendance.<base_domain> +short     # must list the 4 awsdns servers
```

### 5. Regional stacks

Apply us-east-1 first, then us-east-2:

```sh
for r in us-east-1 us-east-2; do
  (cd envs/dev/$r && terraform init && terraform plan -out=tfplan && terraform apply tfplan)
done
```

- Each apply waits for the ACM certificate to validate. This takes a few minutes once the NS delegation from step 4 works.
- Each address in `alarm_emails` receives an **AWS Notification – Subscription Confirmation** email per region. Click the link, or alarms won't be delivered.
- No real email yet? Set `enable_sns = false` in both regional stacks **and** in `envs/dev/global-dns`. Alarms are still created in CloudWatch, but send no notifications.

### 6. Global DNS records and dashboard

```sh
cd envs/dev/global-dns
terraform init
terraform apply
terraform output service_url
cd -
```

### 7. Verify

```sh
curl -sI http://dev.attendance.<base_domain> | head -1      # HTTP/1.1 301 (redirect to HTTPS)
curl -s https://dev.attendance.<base_domain> | grep -o "Welcome to nginx!"
```

In the AWS console, check:
- **Route 53 → Health checks:** both are *Healthy*.
- **ECS:** 3 tasks running in each region.
- **CloudWatch → Dashboards → `attendance-service-dev`:** data for both regions.

### Run without a domain

Set these in the tfvars, and leave `base_domain` unset:

| File | Set |
| --- | --- |
| `envs/dev/global/terraform.tfvars` | `enable_dns_zone = false` |
| `envs/dev/us-east-1/terraform.tfvars`, `envs/dev/us-east-2/terraform.tfvars` | `enable_certificate = false` |
| `envs/dev/global-dns/terraform.tfvars` | `enable_dns_records = false` |

Then run steps 3, 5 and 6, and skip step 4. Each region serves HTTP at `terraform output alb_dns_name`, run in `envs/dev/us-east-1` or `envs/dev/us-east-2`.

### Tear down (reverse order)

1. `envs/dev/global-dns`: `terraform destroy`.
2. Each regional stack:
   1. Set `enable_alb_deletion_protection = false` in its tfvars and run `terraform apply`.
   2. Empty the ALB access-log bucket `attendance-service-dev-<use1|use2>-alb-logs-<company>`, including object versions.
   3. Run `terraform destroy`.
3. `envs/dev/global`: `terraform destroy`, then remove the NS record at your DNS provider.
4. `bootstrap/dev`: the state bucket is protected by `prevent_destroy`. Delete it manually only when no stack state is left.

## Repository layout

```text
bootstrap/<env>/        per-environment S3 state bucket (local state, applied once)
modules/templates/      security-group, iam-role, iam-policy (the only place SGs/IAM are declared)
modules/<component>/    vpc (incl. gateway endpoints and regional NAT), route53-zone,
                        acm-certificate, alb, waf, ecs-service, observability,
                        dashboard, route53-latency
envs/<env>/             global, us-east-1, us-east-2, global-dns (module blocks only)
```

Every module and stack has a README with its inputs, outputs, toggles and design notes.

## Configuration

- **Every tunable setting is a module variable** with a sensible default. Override it in the env stack's `main.tf` module block, or expose it as a stack variable and set it in that stack's `terraform.tfvars`.
- **`terraform.tfvars` is gitignored.** Each stack commits a `terraform.tfvars.example` listing its settings.
- **Terraform doesn't allow variables in a few places**, so these stay literal in code: `backend` blocks, `required_version` and provider version constraints, and `lifecycle` meta-arguments (`prevent_destroy`, `create_before_destroy`).
- **AWS protocol constants stay fixed**, because changing them would break the resource. Examples: `sts:AssumeRole`, endpoint type `Gateway`, `0.0.0.0/0` default routes, the ELB log-delivery principal, and SSE-S3 on the ALB log bucket (the only encryption ALB access logs support).

## Cost (dev, both regions, before traffic)

| Item | Approx. per month |
| --- | --- |
| Regional NAT gateways (2 × 3 AZs) | $197 |
| Fargate tasks (2 × 3 × 0.25 vCPU / 0.5 GB) | $54 |
| ALBs (2) | $33 |
| WAF (2 web ACLs, 3 rule groups each) | $16 |
| Route 53 health checks (2), alarms, dashboard, hosted zone | $12 |
| **Total** | **≈ $310** |

Data processing (NAT, ALB LCUs, WAF requests), log ingestion and S3 storage come on top. NAT gateways are the main hourly cost.

## Checks

Run in each stack or module directory:

```sh
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
tflint --init --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
tflint --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
```

Checkov runs once from the repo root:

```sh
docker run --rm -v "$PWD:/repo" -w /repo bridgecrew/checkov:3.3.20 -d . --config-file .checkov.yaml --compact
```

Checkov runs from the pinned Docker image because the Homebrew `checkov` 3.3.20 package ships without its Terraform graph checks. With it, the S3 encryption, logging and replication checks silently don't run.

### Accepted Checkov skips (`.checkov.yaml`)

These skips apply to the **whole repo**, not to a single resource:

| Check | Reason |
| --- | --- |
| CKV_AWS_18 | S3 access logging would need a second log bucket |
| CKV_AWS_144 | No cross-region replication for S3 buckets |
| CKV_AWS_145 | S3 buckets use SSE-S3 (S3-managed keys), not KMS |
| CKV2_AWS_62 | No consumer for S3 event notifications |
| CKV2_AWS_5 | The security-group template doesn't attach its group; callers do |
| CKV2_AWS_11 | VPC flow logs are not used (design decision) |
| CKV2_AWS_38 | No DNSSEC on Route 53 hosted zones (would need a KMS key and a DS record at the parent DNS provider) |
| CKV2_AWS_39 | No Route 53 query logging |
| CKV_AWS_131 | ALB keeps the AWS default `drop_invalid_header_fields = false` (design decision) |
| CKV_AWS_378 | ALB → target traffic is HTTP on port 80 inside the VPC; TLS ends at the ALB |
| CKV2_AWS_28 | WAF is attached by the separate `waf` module, which Checkov can't link to the ALB |
| CKV_AWS_338 | CloudWatch log groups keep logs for less than 1 year (WAF logs: 30 days, design decision) |
| CKV_AWS_249 | False positive: the ECS execution and task roles are separate roles (`<prefix>-ecs-execution`, `<prefix>-ecs-task`); both come from the iam-role template, so Checkov resolves them as equal |
| CKV_AWS_65 | False positive: Container Insights is enabled by default in `ecs-service`, but Checkov can't resolve values passed from an env stack's variables into a module |
| CKV_AWS_26 | The SNS alarm topic is unencrypted: CloudWatch can't publish to a topic encrypted with the AWS-managed `aws/sns` key, and alarm messages hold no application data |
| CKV_AWS_158 | CloudWatch log groups use the default CloudWatch Logs encryption, not a customer KMS key |
| CKV_AWS_394 | The AZ list isn't pinned. The VPC takes the first 3 AZs sorted by name, and new AZs get later letters, so the selection doesn't change. |

Because the skips are repo-wide, check this table when adding a new module so that a real finding isn't hidden.
