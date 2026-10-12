# ecs-service

Runs the attendance service (simulated by the **official nginx image**) on **ECS Fargate** in a region's private subnets, behind the ALB target group, with rolling deployments, a circuit breaker and target-tracking autoscaling.

## Resources

Values shown are the variable defaults; each can be overridden (see Inputs).

| Resource | Purpose |
| --- | --- |
| `aws_ecs_cluster.this` | `<name_prefix>-cluster`, Container Insights `enabled` (standard) |
| `aws_ecs_cluster_capacity_providers.this` | `FARGATE` only, so no Fargate Spot |
| `aws_cloudwatch_log_group.this` | `/ecs/<name_prefix>-nginx`, 30-day retention |
| `module.task_security_group` (template) | `<name_prefix>-ecs-task`: container port **from the ALB security group only**; all egress (Docker Hub pulls through NAT) |
| `module.execution_logs_policy` (template) | `logs:CreateLogStream` and `logs:PutLogEvents` on this log group only |
| `module.execution_role` (template) | `<name_prefix>-ecs-execution`, trusted by `ecs-tasks.amazonaws.com` (same-account condition), with the policy above |
| `module.task_role` (template) | `<name_prefix>-ecs-task`, no permissions yet (the database is deferred) |
| `aws_ecs_task_definition.this` | `awsvpc`, Fargate, 0.25 vCPU / 512 MiB, `X86_64`, nginx `1.30.5@sha256:9bf97bd7…39edb` on port 80, `awslogs` driver |
| `aws_ecs_service.this` | `<name_prefix>-nginx`, 3 tasks, no public IP, rolling 100% / 200%, circuit breaker with rollback, 30 s health-check grace, registered in the ALB target group |
| `aws_appautoscaling_target.this` | 3 to 6 tasks |
| `aws_appautoscaling_policy.requests` | Target tracking on `ALBRequestCountPerTarget` = 1000 |
| `aws_appautoscaling_policy.cpu` | Target tracking on `ECSServiceAverageCPUUtilization` = 60% |

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name_prefix` | string | — (required) | Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1. |
| `vpc_id` | string | — (required) | ID of the VPC for the task security group. |
| `private_subnet_ids` | list(string) | — (required) | Private subnet IDs (one per AZ) the tasks run in. |
| `alb_security_group_id` | string | — (required) | ID of the ALB security group, the only source allowed to reach the tasks. |
| `target_group_arn` | string | — (required) | ARN of the ALB target group the service registers its tasks in. |
| `alb_arn_suffix` | string | — (required) | ARN suffix of the ALB, used by the ALBRequestCountPerTarget scaling policy. |
| `target_group_arn_suffix` | string | — (required) | ARN suffix of the target group, used by the ALBRequestCountPerTarget scaling policy. |
| `container_image` | string | `"nginx:1.30.5@sha256:9bf97bd7714f5e24c1ccd545ecb9eb5435cb6d109c97cebb15e7e455e0239edb"` | Container image, pinned by tag and digest (no latest). |
| `container_name` | string | `"nginx"` | Name of the container in the task definition (used by the ALB registration). |
| `container_port` | number | `80` | Port the container listens on. |
| `task_cpu` | number | `256` | Task CPU units (256 = 0.25 vCPU). |
| `task_memory` | number | `512` | Task memory in MiB. Must be a valid Fargate combination with task_cpu. |
| `cpu_architecture` | string | `"X86_64"` | CPU architecture of the tasks. |
| `platform_version` | string | `"LATEST"` | Fargate platform version. |
| `desired_count` | number | `3` | Initial number of tasks. After creation, autoscaling owns the count (changes here are ignored). |
| `deployment_minimum_healthy_percent` | number | `100` | Minimum share of desired tasks that must stay healthy during a deployment. |
| `deployment_maximum_percent` | number | `200` | Maximum share of desired tasks that may run during a deployment. |
| `enable_circuit_breaker` | bool | `true` | Stop a failing deployment and roll back to the last working task definition. |
| `health_check_grace_period_seconds` | number | `30` | Seconds after a task starts during which failed ALB health checks are ignored. |
| `enable_autoscaling` | bool | `true` | Scale the service with target tracking on ALB requests per task and CPU. |
| `min_capacity` | number | `3` | Minimum number of tasks when autoscaling is enabled. |
| `max_capacity` | number | `6` | Maximum number of tasks when autoscaling is enabled. |
| `requests_per_target` | number | `1000` | Target ALB requests per task per minute for the ALBRequestCountPerTarget policy. |
| `cpu_target_percent` | number | `60` | Target average CPU utilisation (%) for the CPU policy. |
| `scale_in_cooldown` | number | `300` | Seconds to wait after a scale-in before another scale-in. |
| `scale_out_cooldown` | number | `60` | Seconds to wait after a scale-out before another scale-out. |
| `enable_container_insights` | bool | `true` | Turn on CloudWatch Container Insights for the cluster. |
| `container_insights_mode` | string | `"enabled"` | Container Insights level when enabled: enabled (standard) or enhanced (more metrics, extra cost). |
| `log_retention_days` | number | `30` | Days to keep container logs in CloudWatch Logs. |
| `log_group_kms_key_arn` | string | `null` | KMS key ARN to encrypt the container log group. null uses CloudWatch Logs default encryption. |
| `enable_execute_command` | bool | `false` | Allow ECS Exec (interactive shell into running tasks). Keep false unless debugging. |

## Outputs

| Name | Description |
| --- | --- |
| `cluster_name` / `cluster_arn` | ECS cluster (`ClusterName` metric dimension) |
| `service_name` | ECS service (`ServiceName` metric dimension) |
| `task_definition_arn` | Current task definition revision |
| `task_security_group_id` | Allowed source for downstream services (e.g. DAX later) |
| `log_group_name` | Container log group |
| `execution_role_arn` / `task_role_arn` | IAM roles |

## Toggles

| Toggle | Default | Effect when `false` |
| --- | --- | --- |
| `enable_autoscaling` | `true` | No scaling target or policies; the service stays at `desired_count` |
| `enable_circuit_breaker` | `true` | Failed deployments are not stopped or rolled back automatically |
| `enable_container_insights` | `true` | Cluster setting `containerInsights = disabled` |

## Example

```hcl
module "ecs_service" {
  source                  = "../../../modules/ecs-service"
  name_prefix             = "attendance-service-dev-use1"
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  alb_security_group_id   = module.alb.security_group_id
  target_group_arn        = module.alb.target_group_arn
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
}
```

## Design notes

- **Image pinned by tag and digest.** `nginx:1.30.5` is the current stable release (Debian trixie, published 2026-10-06). The digest is the multi-arch index, so the same value works for `X86_64` and `ARM64`. Validation rejects unpinned images and `latest`.
  - To upgrade, look up the new digest (`docker buildx imagetools inspect nginx:<version>`) and set `container_image`.
- **Least-privilege execution role.** Instead of AWS's `AmazonECSTaskExecutionRolePolicy`, which also grants ECR pulls and log writes everywhere, the custom policy allows only writing to this service's log group. Docker Hub pulls need no IAM.
  - If images move to ECR, add `ecr:GetAuthorizationToken` and the ECR pull actions.
- **Separate roles.** The execution role is used by the ECS agent; the task role is used by the containers. Checkov CKV_AWS_249 falsely reports them as equal, because both come from the same template, so that check is skipped.
- **`desired_count` is ignored after creation** (`ignore_changes`). This stops Terraform from fighting autoscaling. Change capacity with `min_capacity` and `max_capacity`.
- **Zero-downtime rolling deployments.** With 100% minimum healthy and 200% maximum, new tasks must pass the ALB health check before old ones stop. The circuit breaker rolls back a deployment whose tasks keep failing.
- **AZ spread.** ECS spreads Fargate tasks across the given subnets (one per AZ). Keep the count a multiple of the AZ count so each AZ carries an equal share.
- **Two scaling policies.** ECS scales out when *either* policy asks for more tasks and scales in only when *both* allow it.
- **ECS Exec is off** by default (`enable_execute_command`).
- **Root filesystem is writable** because the official nginx image writes to `/var/cache/nginx` and `/var/run`, and it runs as root. Hardening path: an unprivileged nginx image on port 8080 with a read-only root filesystem and all Linux capabilities dropped.

## Cost (billed hourly)

- **Fargate:** about $0.04048 per vCPU-hour plus $0.004445 per GB-hour (us-east-1). A 0.25 vCPU / 0.5 GB task is about $0.0124/h, so 3 tasks are about $27/month per region, or about $54/month for dev across both regions. Scaling to 6 tasks doubles that while scaled out.
- **Container Insights (standard) and logs:** CloudWatch metrics and log ingestion/storage.
