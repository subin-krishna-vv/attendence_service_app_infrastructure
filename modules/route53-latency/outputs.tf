output "record_fqdn" {
  description = "Name users resolve; Route 53 answers with the lowest-latency healthy region's ALB."
  value       = var.record_name
}

output "health_check_ids" {
  description = "Route 53 health check IDs keyed by region (empty when health checks are disabled)."
  value       = { for k, hc in aws_route53_health_check.this : k => hc.id }
}

output "alarm_names" {
  description = "Health check alarm names keyed by region (empty when alarms are disabled)."
  value       = { for k, a in aws_cloudwatch_metric_alarm.health : k => a.alarm_name }
}
