module "dns_zone" {
  source = "../../../modules/route53-zone"

  domain_name = "${var.env}.attendance.${var.base_domain}"
}
