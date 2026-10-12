output "state_bucket_name" {
  description = "Name of the environment's Terraform state bucket, used as `bucket` in every stack's backend block."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_arn" {
  description = "ARN of the environment's Terraform state bucket."
  value       = aws_s3_bucket.state.arn
}

output "state_bucket_region" {
  description = "Region of the state bucket, used as `region` in every stack's backend block."
  value       = aws_s3_bucket.state.bucket_region
}
