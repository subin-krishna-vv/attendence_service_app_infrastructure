# Classroom Attendance Service — Infrastructure

Terraform for an AWS-hosted Classroom attendance service. The service itself is simulated by the **default nginx welcome page**.

## Service level objectives

| SLO | Target | Measured at |
| --- | --- | --- |
| Success rate | 99.99% of requests are not 5xx (≈ 4 min 19 s of failure per 30 days) | ALB: 1 − (`HTTPCode_ELB_5XX_Count` + `HTTPCode_Target_5XX_Count`) / `RequestCount` |
| Latency | 99.99% of responses complete in < 300 ms | ALB: `TargetResponseTime` p99.99 |

Both are request-based over a rolling 30 days. 4xx responses are excluded.

## Architecture

```text
                     Students and teachers
                              |
         Route 53: <env-based domain> (latency records + health checks)
                 /                              \
     us-east-1 (active)                    us-east-2 (active)
     WAF -> ALB (public, 3 AZs, TLS)       WAF -> ALB (public, 3 AZs, TLS)
            |                                     |
     ECS Fargate, nginx :80                ECS Fargate, nginx :80
       (private app subnets, 3 AZs)          (private app subnets, 3 AZs)
            |                                     |
     DAX (private data subnets)            DAX (private data subnets)
            |                                     |
     DynamoDB replica  <== global table replication ==>  DynamoDB replica

     Observability: Amazon CloudWatch (SLIs, alarms, dashboards) across both regions
```

How this meets the SLOs:

- **Active-active across two regions.** Route 53 latency routing with health checks steers traffic away from a failed region.
- **Three AZs per region.** Each region is sized to carry 100% of peak.
- **Rolling deployments** at 100% minimum healthy, with circuit-breaker rollback.
- **CloudWatch SLIs** are measured at the ALB, with alarms and a dashboard.

The nginx placeholder does not read DynamoDB or DAX. The data layer, its networking and its IAM are provisioned so they are ready for the real service.

## Repository layout

```text
bootstrap/<env>/        per-environment S3 state bucket (local state, applied once)
modules/templates/      security-group, iam-role, iam-policy (the only place SGs/IAM are declared)
modules/<component>/    vpc, vpc-endpoints, acm-certificate, alb, waf, ecs-service,
                        dynamodb-global-table, dax, observability, route53-latency
envs/<env>/             global-data, us-east-1, us-east-2, global-dns (module blocks only)
```

## Prerequisites

- Terraform `~> 1.16.1`, AWS provider `~> 6.68`
- [tflint](https://github.com/terraform-linters/tflint) (AWS ruleset pinned in `.tflint.hcl`) and Docker (for [checkov](https://www.checkov.io/))
- AWS credentials through the standard credential chain, e.g. `export AWS_PROFILE=<profile>` or an SSO session. No profile is hard-coded.

## Apply order (per environment)

1. `bootstrap/<env>`, once
2. `envs/<env>/global-data`
3. `envs/<env>/us-east-1`, then `envs/<env>/us-east-2`
4. `envs/<env>/global-dns`

State: one S3 bucket per environment (`attendance-service-<env>-tfstate-<account_id>`), key `<stack>/terraform.tfstate`, native S3 locking (`use_lockfile = true`).

## Checks

Run in each stack or module directory:

```sh
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
tflint --init --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
tflint --config="$(git rev-parse --show-toplevel)/.tflint.hcl"
terraform test
```

`terraform test` applies to modules only. It uses mock providers, so it has no AWS cost.

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

Because the skips are repo-wide, check this table when adding a new module so that a real finding isn't hidden.

## Known deviations from a hardened design (deliberate)

- **nginx runs as root on port 80** (the official image). Hardening path: an unprivileged image on 8080, a read-only root filesystem, and dropping all Linux capabilities.
- **Images are pulled from Docker Hub through NAT.** This puts a public dependency in the scaling path, and anonymous pull rate limits apply. ECR interface endpoints already exist for a later move to ECR.
- **VPC flow logs are off by default** (a toggle). Checkov flags this.
- **Security groups allow all outbound traffic.** Inbound rules (security-group sources wherever possible) are the control point. See [modules/templates/security-group](modules/templates/security-group/README.md).
- **One AWS account hosts all environments.** Separate accounts per environment are the production target.
- **State buckets use SSE-S3 (not KMS) and are not replicated across regions**, and have no access logging, event notifications or TLS-only bucket policy. See [bootstrap/dev/README.md](bootstrap/dev/README.md).
