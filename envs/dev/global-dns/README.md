# envs/dev/global-dns

Cross-region resources for the **dev** environment. Apply this stack **last**, after `envs/dev/us-east-1` and `envs/dev/us-east-2`, because it looks up both regions' ALBs and the us-east-1 alarm topic.

| Module | Creates |
| --- | --- |
| `route53_latency` (`modules/route53-latency`) | Latency-routed `dev.attendance.<base_domain>` → both ALBs, Route 53 health checks, health check alarms |
| `dashboard` (`modules/dashboard`, `count` = `enable_dashboard`) | One CloudWatch dashboard with a column per region |

## State

S3 backend `attendance-service-dev-tfstate-abc`, key `global-dns/terraform.tfstate`, native locking.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project` | string | `"attendance-service"` | Project name, used for the `project` tag. |
| `env` | string | `"dev"` | Environment name, used in the domain name and the `env` tag. |
| `owner` | string | `"devops-team"` | Owning team, used for the `owner` tag. |
| `region` | string | `"us-east-1"` | Provider region. Must be us-east-1: Route 53 health check metrics (and their alarms) only exist there. |
| `base_domain` | string | — (required) | Base domain the service lives under, e.g. example.com. |
| `service_subdomain` | string | `"attendance"` | Subdomain label of the service under base_domain. The env domain is <env>.<service_subdomain>.<base_domain>. |
| `regions` | list(object) | see `variables.tf` | Regional stacks to route to and chart, with the name_prefix each used. |
| `enable_health_checks` | bool | `true` | Create Route 53 health checks for each region's ALB. |
| `enable_health_check_alarms` | bool | `true` | Create a CloudWatch alarm per health check. |
| `alarm_topic_name` | string | `"attendance-service-dev-use1-alarms"` | Existing us-east-1 SNS topic (from the us-east-1 observability module) that health check alarms notify. |
| `enable_dashboard` | bool | `true` | Create the cross-region CloudWatch dashboard. |
| `dashboard_name` | string | `"attendance-service-dev"` | Name of the cross-region CloudWatch dashboard. |

## Usage

```sh
export AWS_PROFILE=<your-profile>
cd envs/dev/global-dns
cp terraform.tfvars.example terraform.tfvars   # then set base_domain
terraform init
terraform plan
terraform apply
terraform output service_url
```

## Outputs

| Name | Description |
| --- | --- |
| `service_url` | `https://dev.attendance.<base_domain>` |
| `health_check_ids` | Route 53 health check IDs by region |
| `dashboard_name` | Dashboard name, or `null` when disabled |

## Notes

- **The provider region must stay `us-east-1`.** Route 53 health check metrics, and so their alarms, exist only there. The dashboard is also created there and shows both regions.
- **`regions` must match the `name_prefix` each regional stack used.** That's how the ALBs, target groups, ECS services and web ACLs are found.
