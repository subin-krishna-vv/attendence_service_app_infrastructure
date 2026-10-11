module "dns_zone" {
  source = "../../../modules/route53-zone"

  domain_name   = "${var.env}.${var.service_subdomain}.${var.base_domain}"
  comment       = var.zone_comment
  force_destroy = var.zone_force_destroy
}
