output "arn" {
  description = "ARN of the IAM policy, for attaching through the iam-role template."
  value       = aws_iam_policy.this.arn
}

output "name" {
  description = "Name of the IAM policy."
  value       = aws_iam_policy.this.name
}
