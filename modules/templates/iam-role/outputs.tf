output "arn" {
  description = "ARN of the IAM role."
  value       = aws_iam_role.this.arn
}

output "name" {
  description = "Name of the IAM role."
  value       = aws_iam_role.this.name
}

output "unique_id" {
  description = "Stable unique ID of the IAM role."
  value       = aws_iam_role.this.unique_id
}
