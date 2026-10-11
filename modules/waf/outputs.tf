output "web_acl_arn" {
  description = "ARN of the web ACL."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "ID of the web ACL."
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_name" {
  description = "Name of the web ACL (WebACL dimension in CloudWatch metrics)."
  value       = aws_wafv2_web_acl.this.name
}

output "log_group_name" {
  description = "Name of the WAF log group, or null when logging is disabled."
  value       = one(aws_cloudwatch_log_group.this[*].name)
}
