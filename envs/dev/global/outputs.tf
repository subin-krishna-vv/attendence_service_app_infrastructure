output "zone_id" {
  description = "Hosted zone ID for <env>.<service_subdomain>.<base_domain>, or null when enable_dns_zone is false."
  value       = one(module.dns_zone[*].zone_id)
}

output "zone_name" {
  description = "Domain name of the env hosted zone, or null when enable_dns_zone is false."
  value       = one(module.dns_zone[*].name)
}

output "name_servers" {
  description = "Add these 4 name servers as NS records for zone_name at the base domain's DNS provider (null when enable_dns_zone is false)."
  value       = one(module.dns_zone[*].name_servers)
}
