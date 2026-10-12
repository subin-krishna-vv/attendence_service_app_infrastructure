output "service_url" {
  description = "URL of the attendance service (Route 53 sends each client to the closest healthy region), or null when enable_dns_records is false."
  value       = var.enable_dns_records ? "https://${module.route53_latency[0].record_fqdn}" : null
}

output "health_check_ids" {
  description = "Route 53 health check IDs keyed by region (empty when DNS records or health checks are disabled)."
  value       = var.enable_dns_records ? module.route53_latency[0].health_check_ids : {}
}

output "dashboard_name" {
  description = "Name of the cross-region CloudWatch dashboard, or null when disabled."
  value       = one(module.dashboard[*].dashboard_name)
}
