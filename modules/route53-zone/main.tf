resource "aws_route53_zone" "this" {
  name          = var.domain_name
  comment       = coalesce(var.comment, try("Public zone for ${var.domain_name}", "Public zone"))
  force_destroy = var.force_destroy
}
