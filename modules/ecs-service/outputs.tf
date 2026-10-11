output "cluster_name" {
  description = "Name of the ECS cluster (ClusterName dimension in CloudWatch metrics)."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Name of the ECS service (ServiceName dimension in CloudWatch metrics)."
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN of the current task definition revision."
  value       = aws_ecs_task_definition.this.arn
}

output "task_security_group_id" {
  description = "ID of the task security group, the allowed source for downstream services (e.g. DAX later)."
  value       = module.task_security_group.id
}

output "log_group_name" {
  description = "Name of the container log group."
  value       = aws_cloudwatch_log_group.this.name
}

output "execution_role_arn" {
  description = "ARN of the task execution role."
  value       = module.execution_role.arn
}

output "task_role_arn" {
  description = "ARN of the task role, for attaching application permissions later."
  value       = module.task_role.arn
}
