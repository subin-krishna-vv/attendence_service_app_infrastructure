# dashboard

Creates **one CloudWatch dashboard** that shows every region **side by side**, one column per region. It's used by the env's `global-dns` stack, which is applied after both regional stacks so that their ALBs and target groups exist.

## Resources

| Resource | Purpose |
| --- | --- |
| `data.aws_lb.this` (per region) | Finds `<name_prefix>-alb` **in that region** (AWS provider 6 per-resource `region`) to get its metric dimension |
| `data.aws_lb_target_group.this` (per region) | Finds `<name_prefix>-tg` in that region |
| `aws_cloudwatch_dashboard.this` | The dashboard, created in the provider's region (us-east-1) |

Widgets in each region's column (defaults):

| Widget | Metrics |
| --- | --- |
| Header | Region name |
| Success rate (%) | `100 − 100 × (ELB 5xx + target 5xx) / requests`, with a **99.99 %** SLO line |
| Target response time | `TargetResponseTime` p50 / p99 / p99.99, with a **300 ms** SLO line |
| Requests | `RequestCount` |
| 5xx errors | `HTTPCode_ELB_5XX_Count`, `HTTPCode_Target_5XX_Count` |
| Targets | `HealthyHostCount`, `UnHealthyHostCount` |
| Running tasks | `ECS/ContainerInsights` `RunningTaskCount` |
| ECS CPU and memory | `AWS/ECS` `CPUUtilization`, `MemoryUtilization` |
| WAF requests | `AllowedRequests` (all) and `CountedRequests` per managed rule group |

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `dashboard_name` | string | — (required) | Name of the CloudWatch dashboard, e.g. attendance-service-dev. |
| `regions` | list(object) | — (required) | Regions to show side by side, each with the name_prefix its regional stack used (e.g. attendance-service-dev-use1). |
| `alb_name_suffix` | string | `"-alb"` | Suffix the alb module appends to name_prefix for the ALB name. |
| `target_group_name_suffix` | string | `"-tg"` | Suffix the alb module appends to name_prefix for the target group name. |
| `ecs_cluster_name_suffix` | string | `"-cluster"` | Suffix the ecs-service module appends to name_prefix for the cluster name. |
| `ecs_service_name_suffix` | string | `"-nginx"` | Suffix the ecs-service module appends to name_prefix for the service name. |
| `web_acl_name_suffix` | string | `"-waf"` | Suffix the waf module appends to name_prefix for the web ACL name. |
| `include_waf_widget` | bool | `true` | Show WAF allowed and counted requests per region. |
| `waf_rule_metric_names` | list(string) | see `variables.tf` | Rule metric names to chart in the WAF widget (the waf module uses the rule group names). |
| `success_slo_percent` | number | `99.99` | Success SLO drawn as a horizontal line on the success-rate widget. |
| `latency_threshold_seconds` | number | `0.3` | Latency SLO threshold drawn as a horizontal line on the latency widget. |
| `latency_percentiles` | list(string) | `["p50", "p99", "p99.99"]` | TargetResponseTime percentiles shown on the latency widget. |
| `period` | number | `60` | Default metric period in seconds for all widgets. |
| `widget_height` | number | `6` | Height of each metric widget in grid units. |

## Outputs

| Name | Description |
| --- | --- |
| `dashboard_name` | Dashboard name |
| `dashboard_arn` | Dashboard ARN |

## Toggles

| Toggle | Where | Default | Effect when `false` |
| --- | --- | --- | --- |
| `enable_dashboard` | **env stack**: `count` on the `module "dashboard"` block | `true` | No dashboard |
| `include_waf_widget` | module variable | `true` | No WAF widget (for example when WAF is disabled) |

## Example

```hcl
module "dashboard" {
  source = "../../../modules/dashboard"
  count  = var.enable_dashboard ? 1 : 0

  dashboard_name = "attendance-service-dev"
  regions = [
    { region = "us-east-1", name_prefix = "attendance-service-dev-use1" },
    { region = "us-east-2", name_prefix = "attendance-service-dev-use2" },
  ]
}
```

## Design notes

- **Lookup by name, no shared state.** The ALB and target group are found with data sources in each region. The ECS cluster, ECS service and WAF names are derived from `name_prefix` plus the same suffixes the `alb`, `ecs-service` and `waf` modules use (`-alb`, `-tg`, `-cluster`, `-nginx`, `-waf`). If those modules' naming changes, update the `*_name_suffix` variables.
- **Apply order.** The data sources fail if a region's ALB doesn't exist yet, so apply both regional stacks before `global-dns`.
- **Layout.** Each region gets an equal share of the 24-unit grid (12 each for 2 regions), and widgets stack in the same order so rows line up across regions.
- **The success widget is a display, not the alarm.** It divides by all requests with no minimum. Alarms (with the low-traffic guard) are in the regional `observability` module.
- Cost: $3/month per dashboard (the first 3 dashboards in an account are free). Nothing is billed hourly.
