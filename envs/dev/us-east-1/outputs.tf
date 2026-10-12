output "name_prefix" {
  description = "Resource name prefix of this stack; global-dns uses it to find the ALB, target group, ECS service and web ACL."
  value       = local.name_prefix
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "certificate_arn" {
  description = "ARN of the validated ACM certificate, or null when enable_certificate is false."
  value       = one(module.certificate[*].certificate_arn)
}

output "https_enabled" {
  description = "Whether the ALB serves HTTPS (enable_https and enable_certificate both true)."
  value       = local.https_enabled
}

output "alb_dns_name" {
  description = "DNS name of the ALB (the regional endpoint behind the latency record)."
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Canonical hosted zone ID of the ALB."
  value       = module.alb.zone_id
}

output "alb_access_logs_bucket" {
  description = "Name of the ALB access-log bucket."
  value       = module.alb.access_logs_bucket
}

output "web_acl_arn" {
  description = "ARN of the WAF web ACL, or null when WAF is disabled."
  value       = one(module.waf[*].web_acl_arn)
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = module.ecs_service.cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service."
  value       = module.ecs_service.service_name
}

output "alarm_topic_arn" {
  description = "ARN of the SNS alarm topic."
  value       = module.observability.alarm_topic_arn
}
