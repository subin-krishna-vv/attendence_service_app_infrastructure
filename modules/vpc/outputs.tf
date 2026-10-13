output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB), in AZ name order."
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs (ECS tasks, DAX), in AZ name order."
  value       = [for s in aws_subnet.private : s.id]
}

output "public_route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "ID of the private route table, for S3 and DynamoDB gateway endpoints."
  value       = aws_route_table.private.id
}

output "nat_gateway_id" {
  description = "ID of the regional NAT gateway, or null when disabled."
  value       = one(aws_nat_gateway.this[*].id)
}

output "internet_gateway_id" {
  description = "ID of the internet gateway."
  value       = aws_internet_gateway.this.id
}

output "s3_endpoint_id" {
  description = "ID of the S3 gateway endpoint, or null when disabled."
  value       = one(aws_vpc_endpoint.s3[*].id)
}

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB gateway endpoint, or null when disabled."
  value       = one(aws_vpc_endpoint.dynamodb[*].id)
}
