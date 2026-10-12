locals {
  domain_name = var.base_domain == null ? null : "${var.env}.${var.service_subdomain}.${var.base_domain}"
}

module "dns_zone" {
  source = "../../../modules/route53-zone"
  count  = var.enable_dns_zone ? 1 : 0

  domain_name   = local.domain_name
  comment       = var.zone_comment
  force_destroy = var.zone_force_destroy
}
