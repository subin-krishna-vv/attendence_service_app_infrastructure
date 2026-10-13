# route53-latency

Points the environment's domain (e.g. `dev.attendance.<base_domain>`) at **every region's ALB with latency-based routing**. Route 53 answers each client with the lowest-latency **healthy** region. Each region gets a **Route 53 health check** and a CloudWatch alarm on that check.

## Resources

Values shown are the variable defaults; each can be overridden (see Inputs).

| Resource | Per | Purpose |
| --- | --- | --- |
| `data.aws_route53_zone.this` | — | Looks up the env's public zone by name |
| `data.aws_lb.this` | region | Finds `<name_prefix>-alb` in that region (provider 6 per-resource `region`) |
| `aws_route53_health_check.this` | region | HTTPS to the ALB's DNS name on 443, path `/`, every **10 s**, unhealthy after **3** failures, SNI on |
| `aws_route53_record.this` | region | `A` alias to the ALB, `set_identifier = <region>`, latency routing to `<region>`, `evaluate_target_health = true`, linked to the health check |
| `data.aws_sns_topic.alarms` | — | The existing alarm topic, looked up by name |
| `aws_cloudwatch_metric_alarm.health` | region | `AWS/Route53 HealthCheckStatus` < 1 for 1 minute → ALARM and OK to the topic |

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `zone_name` | string | — (required) | Name of the existing public hosted zone, e.g. dev.attendance.example.com. |
| `record_name` | string | — (required) | Record users resolve, e.g. dev.attendance.example.com. Must be zone_name or inside it. |
| `regions` | list(object) | — (required) | Regions to route to, each with the name_prefix its regional stack used (e.g. attendance-service-dev-use1). |
| `alb_name_suffix` | string | `"-alb"` | Suffix the alb module appends to name_prefix for the ALB name. |
| `evaluate_target_health` | bool | `true` | Let Route 53 also use the ALB's own target health when answering queries. |
| `enable_health_checks` | bool | `true` | Create a Route 53 health check per region and attach it to that region's record. |
| `health_check_type` | string | `"HTTPS"` | Protocol of the health checks. |
| `health_check_port` | number | `443` | Port the health checks connect to. |
| `health_check_path` | string | `"/"` | Path the health checks request. |
| `health_check_request_interval` | number | `10` | Seconds between checks from each checker: 10 (fast, extra cost) or 30. |
| `health_check_failure_threshold` | number | `3` | Consecutive failures before an endpoint is unhealthy. |
| `health_check_measure_latency` | bool | `false` | Publish Route 53 checker latency metrics (extra cost). |
| `health_check_regions` | list(string) | `null` | Route 53 checker regions (at least 3). null uses all checker regions. |
| `enable_health_check_alarms` | bool | `true` | Create a CloudWatch alarm per health check. Route 53 health check metrics only exist in us-east-1, so the provider must be us-east-1. |
| `alarm_topic_name` | string | `null` | Name of an existing SNS topic in the provider region that health check alarms notify (e.g. attendance-service-dev-use1-alarms). null creates the alarms without notifications. |
| `alarm_period` | number | `60` | Seconds per evaluation period of the health check alarms. |
| `alarm_evaluation_periods` | number | `1` | Periods a health check must be unhealthy before its alarm fires. |

## Outputs

| Name | Description |
| --- | --- |
| `record_fqdn` | The name users resolve |
| `health_check_ids` | Health check IDs by region |
| `alarm_names` | Health check alarm names by region |

## Toggles

| Toggle | Default | Effect when `false` |
| --- | --- | --- |
| `enable_health_checks` | `true` | No health checks or alarms. Records rely only on `evaluate_target_health` (the ALB's own target health). |
| `enable_health_check_alarms` | `true` | Health checks stay, with no CloudWatch alarms |

If `alarm_topic_name` is `null`, the alarms are still created but have no notification actions.

## Example

```hcl
module "route53_latency" {
  source           = "../../../modules/route53-latency"
  zone_name        = "dev.attendance.example.com"
  record_name      = "dev.attendance.example.com"
  alarm_topic_name = "attendance-service-dev-use1-alarms"
  regions = [
    { region = "us-east-1", name_prefix = "attendance-service-dev-use1" },
    { region = "us-east-2", name_prefix = "attendance-service-dev-use2" },
  ]
}
```

## Design notes

- **How failover works.** Each latency record is only served while its health check passes, *and* while the ALB has healthy targets (`evaluate_target_health`). If us-east-1 fails, Route 53 answers every client with us-east-2.
  - Detection takes about 30 seconds (3 failures × 10 s). Clients then pick up the change when resolvers refresh. Alias records to an ALB use a 60-second TTL.
- **The health check hits the ALB's DNS name directly** (design decision). It tests the region itself, independent of our own DNS. Route 53 health checks don't validate the certificate's hostname, so the ALB's `dev.attendance…` certificate is fine. The check passes on a 2xx/3xx response from `/`.
- **Alarms must run in us-east-1.** Route 53 publishes `HealthCheckStatus` only in us-east-1, so run this module with a us-east-1 provider. Alarms reuse the us-east-1 `observability` topic, so the same people are notified.
- **Missing data counts as breaching** on these alarms. A health check that stops reporting is treated as failing.
- **Apply order.** Both regional ALBs and the alarm topic must exist first, so this belongs in `envs/<env>/global-dns`, applied last.

## Cost

Per health check against an AWS endpoint: $0.50/month, plus the optional HTTPS feature and the fast 10 s interval (about $1 each). With `measure_latency` off, that's roughly $2–2.50/month per region. Each alarm costs about $0.10/month. Nothing is billed hourly.
