output "zone_id" {
  description = "ID of the hosted zone, used for ACM validation and latency alias records."
  value       = aws_route53_zone.this.zone_id
}

output "name" {
  description = "Domain name of the hosted zone."
  value       = aws_route53_zone.this.name
}

output "name_servers" {
  description = "The 4 Route 53 name servers. Add them as NS records for this name at the parent domain's DNS provider."
  value       = aws_route53_zone.this.name_servers
}
