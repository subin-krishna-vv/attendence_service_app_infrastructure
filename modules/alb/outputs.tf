output "alb_arn" {
  description = "ARN of the ALB, used for the WAF association."
  value       = aws_lb.this.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the ALB, used as the LoadBalancer dimension in CloudWatch metrics."
  value       = aws_lb.this.arn_suffix
}

output "dns_name" {
  description = "DNS name of the ALB, used as the Route 53 alias target."
  value       = aws_lb.this.dns_name
}

output "zone_id" {
  description = "Canonical hosted zone ID of the ALB, used as the Route 53 alias zone."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group the ECS service registers tasks in."
  value       = aws_lb_target_group.this.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the target group, used as the TargetGroup dimension in CloudWatch metrics."
  value       = aws_lb_target_group.this.arn_suffix
}

output "security_group_id" {
  description = "ID of the ALB security group, the only allowed source for the ECS task security group."
  value       = module.security_group.id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener, or null when enable_https is false."
  value       = one(aws_lb_listener.https[*].arn)
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}

output "access_logs_bucket" {
  description = "Name of the access-log bucket."
  value       = aws_s3_bucket.logs.id
}
