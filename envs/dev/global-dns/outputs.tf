output "service_url" {
  description = "URL of the attendance service; Route 53 sends each client to the closest healthy region."
  value       = "https://${module.route53_latency.record_fqdn}"
}

output "health_check_ids" {
  description = "Route 53 health check IDs keyed by region."
  value       = module.route53_latency.health_check_ids
}

output "dashboard_name" {
  description = "Name of the cross-region CloudWatch dashboard, or null when disabled."
  value       = one(module.dashboard[*].dashboard_name)
}
