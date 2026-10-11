# observability

Creates a region's **SLO alarms** and supporting alarms in CloudWatch, plus an **SNS topic** with email subscriptions that receives every alarm and recovery notification. Each regional stack calls it once, because CloudWatch alarms must be in the same region as their metrics.

The cross-region **dashboard** is a separate `dashboard` module in the `global-dns` stack, which is applied after both regions.

## SLOs and alarms

Values shown are the variable defaults; each can be overridden (see Inputs).

| Alarm | Metric | Fires when |
| --- | --- | --- |
| `<name_prefix>-slo-error-rate` | `100 × (HTTPCode_ELB_5XX_Count + HTTPCode_Target_5XX_Count) / RequestCount`, 5-minute sums | Above **0.01 %** (the 99.99 % success SLO's error budget) in 1 period. Evaluated only when the period has **≥ 1000 requests**; otherwise treated as 0. |
| `<name_prefix>-slo-latency` | `TargetResponseTime` **p99.99**, 1-minute periods | Above **300 ms** in 3 of 3 periods |
| `<name_prefix>-unhealthy-targets` | `UnHealthyHostCount` max | Above 0 in 3 consecutive minutes |
| `<name_prefix>-running-tasks-low` | `ECS/ContainerInsights` `RunningTaskCount` min | Below 3 in 3 consecutive minutes |
| `<name_prefix>-ecs-cpu-high` | `AWS/ECS` `CPUUtilization` average | Above 80 % in 3 consecutive minutes |
| `<name_prefix>-ecs-memory-high` | `AWS/ECS` `MemoryUtilization` average | Above 80 % in 3 consecutive minutes |

Every alarm sends both **ALARM** and **OK** notifications to the topic. Missing data counts as not breaching (`treat_missing_data`).

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name_prefix` | string | — (required) | Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1. |
| `alb_arn_suffix` | string | — (required) | ARN suffix of the ALB (LoadBalancer metric dimension). |
| `target_group_arn_suffix` | string | — (required) | ARN suffix of the target group (TargetGroup metric dimension). |
| `ecs_cluster_name` | string | — (required) | Name of the ECS cluster (ClusterName metric dimension). |
| `ecs_service_name` | string | — (required) | Name of the ECS service (ServiceName metric dimension). |
| `alarm_emails` | list(string) | `[]` | Email addresses subscribed to the alarm topic. Each address must confirm the subscription email from AWS. |
| `sns_kms_master_key_id` | string | `null` | Customer-managed KMS key for the alarm topic. null leaves the topic unencrypted (CloudWatch cannot publish to a topic encrypted with the AWS-managed aws/sns key). |
| `enable_alarms` | bool | `true` | Create the SLO and supporting CloudWatch alarms. |
| `treat_missing_data` | string | `"notBreaching"` | How alarms treat periods with no data. |
| `error_rate_threshold_percent` | number | `0.01` | Error budget in percent: the error-rate alarm fires above this. 0.01 matches a 99.99% success SLO. |
| `error_rate_period` | number | `300` | Seconds per evaluation period of the error-rate alarm. |
| `error_rate_evaluation_periods` | number | `1` | Periods the error rate must breach before the alarm fires. |
| `error_rate_min_requests` | number | `1000` | Minimum requests in a period before the error rate is evaluated (avoids 1-in-10 style alarms at low traffic). |
| `latency_percentile` | string | `"p99.99"` | Percentile of TargetResponseTime the latency alarm watches. |
| `latency_threshold_seconds` | number | `0.3` | Latency SLO threshold in seconds. |
| `latency_period` | number | `60` | Seconds per evaluation period of the latency alarm. |
| `latency_evaluation_periods` | number | `3` | Periods evaluated by the latency alarm. |
| `latency_datapoints_to_alarm` | number | `3` | Breaching periods (out of latency_evaluation_periods) needed to fire the latency alarm. |
| `unhealthy_hosts_threshold` | number | `0` | The alarm fires when more unhealthy targets than this are seen. |
| `min_running_tasks` | number | `3` | The alarm fires when fewer ECS tasks than this are running (Container Insights metric). |
| `cpu_high_percent` | number | `80` | Average ECS service CPU utilisation (%) above which the alarm fires. |
| `memory_high_percent` | number | `80` | Average ECS service memory utilisation (%) above which the alarm fires. |
| `supporting_alarm_period` | number | `60` | Seconds per evaluation period of the supporting (host, task, CPU, memory) alarms. |
| `supporting_alarm_evaluation_periods` | number | `3` | Periods the supporting alarms must breach before they fire. |

## Outputs

| Name | Description |
| --- | --- |
| `alarm_topic_arn` | SNS topic ARN (other alarms, e.g. Route 53 health checks, can publish here) |
| `alarm_names` | Alarm names keyed by purpose; empty when alarms are off |

## Toggles

| Toggle | Default | Effect when `false` |
| --- | --- | --- |
| `enable_alarms` | `true` | No alarms. The topic and subscriptions remain. |

## Example

```hcl
module "observability" {
  source                  = "../../../modules/observability"
  name_prefix             = "attendance-service-dev-use1"
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  ecs_cluster_name        = module.ecs_service.cluster_name
  ecs_service_name        = module.ecs_service.service_name
  alarm_emails            = var.alarm_emails
}
```

```hcl
alarm_emails = ["alerts@example.com"]
```

The second block is the regional stack's `terraform.tfvars`. Add more addresses to the list as needed.

## Design notes

- **Email subscriptions must be confirmed.** AWS sends each address a confirmation email, and nothing is delivered until the link is clicked. `example.com` addresses can't confirm, so replace them before relying on alerts.
- **Error rate uses metric math.** `IF(requests >= N, …, 0)` stops a single 5xx at very low traffic (for example 1 in 10 requests = 10 %) from paging. Below `error_rate_min_requests` the error rate is reported as 0. Errors are still visible on the dashboard.
- **The latency alarm is a direct percentile alarm** (`extended_statistic = "p99.99"`) on the whole ALB. At low traffic p99.99 is effectively the maximum, so one slow request in a minute counts. Requiring 3 of 3 minutes filters out single spikes.
- **These are simple threshold alarms** (design decision), not multi-window burn-rate alarms.
- **The running-tasks alarm needs Container Insights** (on by default in `ecs-service`). If Insights is off the metric is missing, and the alarm stays OK.
- **The SNS topic is unencrypted by default.** CloudWatch can't publish to a topic encrypted with the AWS-managed `aws/sns` key ([AWS re:Post](https://repost.aws/knowledge-center/cloudwatch-configure-alarm-sns)); it needs a customer-managed key whose key policy allows `cloudwatch.amazonaws.com`. Set `sns_kms_master_key_id` to such a key to encrypt. Alarm notifications contain no application data.
- **Thresholds are separate variables.** `error_rate_threshold_percent` is set directly (0.01) rather than computed as `100 - 99.99`, because Terraform's arithmetic gives 0.00999… for that subtraction.

## Cost

- **Alarms:** about $0.10/month each for standard alarms, more for the metric-math and percentile alarms. Six alarms come to roughly $1–2/month per region.
- **SNS email:** free at this volume.
- Nothing is billed hourly.
