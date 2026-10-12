# alb

Creates a region's **internet-facing Application Load Balancer** in the 3 public subnets. It terminates TLS on 443, redirects 80 to 443, and forwards to an `ip` target group on port 80, which the ECS service registers its tasks in. It also creates the ALB's security group (through the template) and an access-log bucket.

## Resources

Values shown are the variable defaults; each can be overridden (see Inputs).

| Resource | Purpose |
| --- | --- |
| `module.security_group` (templates/security-group) | `<name_prefix>-alb`: 80 from `0.0.0.0/0`, plus 443 from `0.0.0.0/0` when HTTPS is on |
| `aws_lb.this` | `<name_prefix>-alb`, internet-facing, deletion protection (toggle), access logs (toggle) |
| `aws_lb_target_group.this` | `<name_prefix>-tg`, `ip`, HTTP/80, deregistration delay 30 s, health check `/` → `200` every 10 s, healthy 2 / unhealthy 2 |
| `aws_lb_listener.https` | 443, `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09`, forwards to the target group |
| `aws_lb_listener.http` | 80, 301 redirect to HTTPS (or forward when HTTPS is off) |
| `aws_s3_bucket.logs` + versioning, SSE-S3, public access block, ownership controls, lifecycle, policy | `<name_prefix>-alb-logs-<company>`; logs expire after 30 days |

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name_prefix` | string | — (required) | Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1. ALB and target group names are limited to 32 characters. |
| `company` | string | — (required) | Company name, used as the access-log bucket name suffix to keep it globally unique. |
| `vpc_id` | string | — (required) | ID of the VPC for the target group and security group. |
| `public_subnet_ids` | list(string) | — (required) | Public subnet IDs (one per AZ) the ALB is placed in. |
| `certificate_arn` | string | `null` | ARN of the validated ACM certificate for the HTTPS listener. Required when enable_https is true. |
| `enable_https` | bool | `true` | Create the HTTPS (443) listener and redirect HTTP (80) to it. When false, port 80 forwards to the target group. |
| `enable_access_logs` | bool | `true` | Send ALB access logs to the access-log bucket. The bucket itself always exists. |
| `enable_deletion_protection` | bool | `true` | Turn on ALB deletion protection. terraform destroy fails until this is set to false and applied. |
| `access_log_retention_days` | number | `30` | Days to keep ALB access logs before they expire. |
| `log_noncurrent_version_expiration_days` | number | `1` | Days to keep overwritten (noncurrent) access-log object versions. |
| `log_abort_incomplete_multipart_upload_days` | number | `7` | Days after which incomplete multipart uploads to the log bucket are aborted. |
| `log_bucket_force_destroy` | bool | `false` | Allow Terraform to delete the access-log bucket even when it holds logs. |
| `ingress_cidr_ipv4` | string | `"0.0.0.0/0"` | IPv4 CIDR allowed to reach the ALB listeners. |
| `http_port` | number | `80` | HTTP listener port. |
| `https_port` | number | `443` | HTTPS listener port. |
| `ssl_policy` | string | `"ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"` | Security policy of the HTTPS listener. |
| `redirect_status_code` | string | `"HTTP_301"` | Status code of the HTTP to HTTPS redirect. |
| `idle_timeout` | number | `60` | Seconds a connection may be idle before the ALB closes it. |
| `enable_http2` | bool | `true` | Allow HTTP/2 between clients and the ALB. |
| `drop_invalid_header_fields` | bool | `false` | Drop HTTP headers with invalid names. AWS default is false. |
| `desync_mitigation_mode` | string | `"defensive"` | How the ALB handles requests that may be HTTP desync (request smuggling) risks. AWS default is defensive. |
| `target_port` | number | `80` | Port the targets (nginx containers) listen on. |
| `target_protocol` | string | `"HTTP"` | Protocol from the ALB to the targets and for health checks. |
| `deregistration_delay` | number | `30` | Seconds the ALB keeps sending in-flight requests to a deregistering target. |
| `health_check_path` | string | `"/"` | Path of the target health check. |
| `health_check_matcher` | string | `"200"` | HTTP codes that mark a target healthy, e.g. 200 or 200-299. |
| `health_check_interval` | number | `10` | Seconds between health checks. |
| `health_check_timeout` | number | `5` | Seconds without a response that count as a failed health check. Must be less than the interval. |
| `health_check_healthy_threshold` | number | `2` | Consecutive successes before a target is healthy. |
| `health_check_unhealthy_threshold` | number | `2` | Consecutive failures before a target is unhealthy. |

## Outputs

| Name | Description |
| --- | --- |
| `alb_arn` | For the WAF association |
| `alb_arn_suffix` | CloudWatch `LoadBalancer` dimension |
| `dns_name` / `zone_id` | Route 53 alias target |
| `target_group_arn` | ECS service load balancer registration |
| `target_group_arn_suffix` | CloudWatch `TargetGroup` dimension |
| `security_group_id` | The only allowed source for the ECS task SG |
| `https_listener_arn` | `null` when HTTPS is off |
| `http_listener_arn` | HTTP listener |
| `access_logs_bucket` | Log bucket name |

## Toggles

| Toggle | Default | Effect when `false` |
| --- | --- | --- |
| `enable_https` | `true` | No 443 listener and no 443 SG rule; port 80 forwards to the targets |
| `enable_access_logs` | `true` | The ALB stops writing logs. **The bucket is kept**, because putting it behind `count` makes Checkov falsely report missing versioning, lifecycle and public access block. An empty bucket costs nothing. |
| `enable_deletion_protection` | `true` | The ALB can be deleted. While `true`, `terraform destroy` fails, which is intentional. |

## Example

```hcl
module "alb" {
  source            = "../../../modules/alb"
  name_prefix       = "attendance-service-dev-use1"
  company           = "abc"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.certificate.certificate_arn
}
```

## Design notes

- **TLS policy:** `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` is AWS's current recommendation and the console default. It allows TLS 1.2 (GCM ciphers only) and TLS 1.3, plus hybrid post-quantum key exchange.
- **Deregistration delay of 30 s** (instead of 300 s). nginx requests are short, so draining finishes quickly and rolling deployments are faster.
- **AWS defaults kept** for `drop_invalid_header_fields` (false) and `desync_mitigation_mode` (`defensive`). This is a deliberate decision; Checkov CKV_AWS_131 is skipped.
- **HTTP to targets (CKV_AWS_378).** TLS ends at the ALB and nginx listens on port 80 inside the private subnets. Re-encrypting to the task is part of the nginx hardening path.
- **WAF (CKV2_AWS_28)** is attached by the `waf` module, so Checkov can't see it from here.
- **Access-log bucket:**
  - SSE-S3 is the only encryption ALB access logs support.
  - The bucket policy allows only `logdelivery.elasticloadbalancing.amazonaws.com` to write, only under `AWSLogs/<this account>/`, and only for this account's load balancers in this region (`aws:SourceArn`). This is the current AWS-recommended policy rather than the legacy ELB-account policy.
  - Versioning protects logs from overwrite; noncurrent versions expire after 1 day.
- **Naming limit:** `<name_prefix>-alb` must fit in 32 characters. `attendance-service-dev-use1` fits, but `attendance-service-staging-use1` does not, so staging needs shorter environment or project codes.

## Cost (billed hourly)

- **ALB:** about $0.0225/h plus $0.008 per LCU-hour. That's roughly $16.40/month per region before traffic.
- **Logs:** S3 storage for 30 days of access logs.
