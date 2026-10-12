output "id" {
  description = "ID of the security group, for attaching it or referencing it from another group's rules."
  value       = aws_security_group.this.id
}

output "arn" {
  description = "ARN of the security group."
  value       = aws_security_group.this.arn
}

output "name" {
  description = "Name of the security group."
  value       = aws_security_group.this.name
}
