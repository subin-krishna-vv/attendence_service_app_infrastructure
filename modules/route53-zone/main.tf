resource "aws_route53_zone" "this" {
  name          = var.domain_name
  comment       = "Public zone for ${var.domain_name}"
  force_destroy = false
}
