resource "aws_route53_zone" "this" {
  name          = var.domain_name
  comment       = coalesce(var.comment, "Public zone for ${var.domain_name}")
  force_destroy = var.force_destroy
}
