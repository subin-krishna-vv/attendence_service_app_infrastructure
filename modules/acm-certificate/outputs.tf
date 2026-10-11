output "certificate_arn" {
  description = "ARN of the validated certificate. Only known once validation completes, so the ALB listener waits for it."
  value       = aws_acm_certificate_validation.this.certificate_arn
}

output "domain_name" {
  description = "Primary domain name of the certificate."
  value       = aws_acm_certificate.this.domain_name
}

output "zone_id" {
  description = "ID of the hosted zone used for validation."
  value       = data.aws_route53_zone.this.zone_id
}
