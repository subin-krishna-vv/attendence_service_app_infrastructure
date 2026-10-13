variable "project" {
  description = "Project name, used in resource names and the `project` tag."
  type        = string
  default     = "attendance-service"
}

variable "env" {
  description = "Environment name, used in resource names, the domain and the `env` tag."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be dev, staging or prod."
  }
}

variable "owner" {
  description = "Owning team, used for the `owner` tag."
  type        = string
  default     = "devops-team"
}

variable "company" {
  description = "Company name, used as the suffix of globally unique S3 bucket names."
  type        = string
  default     = "abc"
}

variable "region" {
  description = "AWS region of this regional stack."
  type        = string
  default     = "us-east-1"
}

variable "region_short" {
  description = "Short region code used in resource names, e.g. use1."
  type        = string
  default     = "use1"
}

variable "base_domain" {
  description = "Base domain the service lives under, e.g. example.com. Set in the gitignored terraform.tfvars. Required when enable_certificate is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_certificate || var.base_domain != null
    error_message = "base_domain is required when enable_certificate is true."
  }
}

variable "enable_certificate" {
  description = "Create the ACM certificate for <env>.<service_subdomain>.<base_domain>. When false, the ALB serves HTTP only (no HTTPS listener or redirect)."
  type        = bool
  default     = true
}

variable "service_subdomain" {
  description = "Subdomain label of the service. The env domain is <env>.<service_subdomain>.<base_domain>."
  type        = string
  default     = "attendance"
}

variable "vpc_cidr" {
  description = "VPC CIDR for this region (non-overlapping /16, see the CIDR plan in the root README)."
  type        = string
  default     = "10.10.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones (one public and one private subnet each)."
  type        = number
  default     = 3
}

variable "enable_nat_gateway" {
  description = "Create the regional NAT gateway (needed for Docker Hub pulls)."
  type        = bool
  default     = true
}

variable "enable_s3_endpoint" {
  description = "Create the S3 gateway endpoint."
  type        = bool
  default     = true
}

variable "enable_dynamodb_endpoint" {
  description = "Create the DynamoDB gateway endpoint."
  type        = bool
  default     = true
}

variable "enable_wildcard_certificate" {
  description = "Add *.<env domain> to the ACM certificate."
  type        = bool
  default     = true
}

variable "enable_https" {
  description = "Create the HTTPS listener and redirect HTTP to it. Only takes effect when enable_certificate is true."
  type        = bool
  default     = true
}

variable "enable_alb_access_logs" {
  description = "Send ALB access logs to the access-log bucket."
  type        = bool
  default     = true
}

variable "alb_access_log_retention_days" {
  description = "Days to keep ALB access logs."
  type        = number
  default     = 30
}

variable "enable_alb_deletion_protection" {
  description = "ALB deletion protection; set false and apply before destroying the stack."
  type        = bool
  default     = true
}

variable "enable_waf" {
  description = "Create and attach the WAF web ACL."
  type        = bool
  default     = true
}

variable "waf_managed_rule_action" {
  description = "count: managed rules only count; none: managed rules block."
  type        = string
  default     = "count"
}

variable "waf_log_retention_days" {
  description = "Days to keep WAF logs in CloudWatch Logs."
  type        = number
  default     = 30
}

variable "container_image" {
  description = "Container image pinned by tag and digest."
  type        = string
  default     = "nginx:1.30.5@sha256:9bf97bd7714f5e24c1ccd545ecb9eb5435cb6d109c97cebb15e7e455e0239edb"
}

variable "task_cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Initial number of tasks (autoscaling owns it afterwards)."
  type        = number
  default     = 3
}

variable "enable_autoscaling" {
  description = "Target-tracking autoscaling on ALB requests per task and CPU."
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum tasks when autoscaling."
  type        = number
  default     = 3
}

variable "max_capacity" {
  description = "Maximum tasks when autoscaling."
  type        = number
  default     = 6
}

variable "requests_per_target" {
  description = "Target ALB requests per task per minute."
  type        = number
  default     = 1000
}

variable "cpu_target_percent" {
  description = "Target average CPU (%)."
  type        = number
  default     = 60
}

variable "enable_circuit_breaker" {
  description = "Roll back failing deployments automatically."
  type        = bool
  default     = true
}

variable "enable_container_insights" {
  description = "CloudWatch Container Insights on the cluster."
  type        = bool
  default     = true
}

variable "container_log_retention_days" {
  description = "Days to keep container logs."
  type        = number
  default     = 30
}

variable "enable_alarms" {
  description = "Create the SLO and supporting CloudWatch alarms."
  type        = bool
  default     = true
}

variable "enable_sns" {
  description = "Create the SNS alarm topic and email subscriptions. When false, alarms exist in CloudWatch but send no notifications (alarm_emails is ignored)."
  type        = bool
  default     = true
}

variable "alarm_emails" {
  description = "Email addresses notified by alarms. Set real addresses only in the gitignored terraform.tfvars."
  type        = list(string)
  default     = []
}
