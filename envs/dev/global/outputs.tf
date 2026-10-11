output "zone_id" {
  description = "Hosted zone ID for <env>.<service_subdomain>.<base_domain>, used by the regional stacks (ACM validation) and global-dns."
  value       = module.dns_zone.zone_id
}

output "zone_name" {
  description = "Domain name of the dev hosted zone."
  value       = module.dns_zone.name
}

output "name_servers" {
  description = "Add these 4 name servers as NS records for zone_name at the base domain's DNS provider."
  value       = module.dns_zone.name_servers
}
