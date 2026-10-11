variable "name_prefix" {
  description = "Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1. ALB and target group names are limited to 32 characters."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name_prefix)) && length(var.name_prefix) <= 28
    error_message = "name_prefix must be lowercase alphanumeric with hyphens and at most 28 characters (so <name_prefix>-alb fits in 32)."
  }
}

variable "company" {
  description = "Company name, used as the access-log bucket name suffix to keep it globally unique."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.company))
    error_message = "company must be lowercase alphanumeric with hyphens (S3 bucket naming rules)."
  }
}

variable "vpc_id" {
  description = "ID of the VPC for the target group and security group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ) the ALB is placed in."
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_ids) >= 2
    error_message = "public_subnet_ids must contain at least 2 subnets in different AZs (ALB requirement)."
  }
}

variable "certificate_arn" {
  description = "ARN of the validated ACM certificate for the HTTPS listener. Required when enable_https is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_https || var.certificate_arn != null
    error_message = "certificate_arn is required when enable_https is true."
  }
}

variable "enable_https" {
  description = "Create the HTTPS (443) listener and redirect HTTP (80) to it. When false, port 80 forwards to the target group."
  type        = bool
  default     = true
}

variable "enable_access_logs" {
  description = "Send ALB access logs to the access-log bucket. The bucket itself always exists."
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Turn on ALB deletion protection. terraform destroy fails until this is set to false and applied."
  type        = bool
  default     = true
}

variable "access_log_retention_days" {
  description = "Days to keep ALB access logs before they expire."
  type        = number
  default     = 30

  validation {
    condition     = var.access_log_retention_days > 0 && floor(var.access_log_retention_days) == var.access_log_retention_days
    error_message = "access_log_retention_days must be a positive whole number."
  }
}

variable "log_noncurrent_version_expiration_days" {
  description = "Days to keep overwritten (noncurrent) access-log object versions."
  type        = number
  default     = 1

  validation {
    condition     = var.log_noncurrent_version_expiration_days >= 1 && var.log_noncurrent_version_expiration_days <= 3650 && floor(var.log_noncurrent_version_expiration_days) == var.log_noncurrent_version_expiration_days
    error_message = "log_noncurrent_version_expiration_days must be a whole number between 1 and 3650."
  }
}

variable "log_abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads to the log bucket are aborted."
  type        = number
  default     = 7

  validation {
    condition     = var.log_abort_incomplete_multipart_upload_days >= 1 && var.log_abort_incomplete_multipart_upload_days <= 3650 && floor(var.log_abort_incomplete_multipart_upload_days) == var.log_abort_incomplete_multipart_upload_days
    error_message = "log_abort_incomplete_multipart_upload_days must be a whole number between 1 and 3650."
  }
}

variable "log_bucket_force_destroy" {
  description = "Allow Terraform to delete the access-log bucket even when it holds logs."
  type        = bool
  default     = false
}

variable "ingress_cidr_ipv4" {
  description = "IPv4 CIDR allowed to reach the ALB listeners."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ingress_cidr_ipv4, 0))
    error_message = "ingress_cidr_ipv4 must be a valid IPv4 CIDR block."
  }
}

variable "http_port" {
  description = "HTTP listener port."
  type        = number
  default     = 80

  validation {
    condition     = var.http_port >= 1 && var.http_port <= 65535 && floor(var.http_port) == var.http_port
    error_message = "http_port must be a whole number between 1 and 65535."
  }
}

variable "https_port" {
  description = "HTTPS listener port."
  type        = number
  default     = 443

  validation {
    condition     = var.https_port >= 1 && var.https_port <= 65535 && floor(var.https_port) == var.https_port
    error_message = "https_port must be a whole number between 1 and 65535."
  }
}

variable "ssl_policy" {
  description = "Security policy of the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"

  validation {
    condition     = startswith(var.ssl_policy, "ELBSecurityPolicy-TLS13-")
    error_message = "ssl_policy must be a TLS 1.3-capable ELBSecurityPolicy-TLS13-* policy."
  }
}

variable "redirect_status_code" {
  description = "Status code of the HTTP to HTTPS redirect."
  type        = string
  default     = "HTTP_301"

  validation {
    condition     = contains(["HTTP_301", "HTTP_302"], var.redirect_status_code)
    error_message = "redirect_status_code must be HTTP_301 or HTTP_302."
  }
}

variable "idle_timeout" {
  description = "Seconds a connection may be idle before the ALB closes it."
  type        = number
  default     = 60

  validation {
    condition     = var.idle_timeout >= 1 && var.idle_timeout <= 4000 && floor(var.idle_timeout) == var.idle_timeout
    error_message = "idle_timeout must be a whole number between 1 and 4000."
  }
}

variable "enable_http2" {
  description = "Allow HTTP/2 between clients and the ALB."
  type        = bool
  default     = true
}

variable "drop_invalid_header_fields" {
  description = "Drop HTTP headers with invalid names. AWS default is false."
  type        = bool
  default     = false
}

variable "desync_mitigation_mode" {
  description = "How the ALB handles requests that may be HTTP desync (request smuggling) risks. AWS default is defensive."
  type        = string
  default     = "defensive"

  validation {
    condition     = contains(["monitor", "defensive", "strictest"], var.desync_mitigation_mode)
    error_message = "desync_mitigation_mode must be monitor, defensive or strictest."
  }
}

variable "target_port" {
  description = "Port the targets (nginx containers) listen on."
  type        = number
  default     = 80

  validation {
    condition     = var.target_port >= 1 && var.target_port <= 65535 && floor(var.target_port) == var.target_port
    error_message = "target_port must be a whole number between 1 and 65535."
  }
}

variable "target_protocol" {
  description = "Protocol from the ALB to the targets and for health checks."
  type        = string
  default     = "HTTP"

  validation {
    condition     = contains(["HTTP", "HTTPS"], var.target_protocol)
    error_message = "target_protocol must be HTTP or HTTPS."
  }
}

variable "deregistration_delay" {
  description = "Seconds the ALB keeps sending in-flight requests to a deregistering target."
  type        = number
  default     = 30

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600 && floor(var.deregistration_delay) == var.deregistration_delay
    error_message = "deregistration_delay must be a whole number between 0 and 3600."
  }
}

variable "health_check_path" {
  description = "Path of the target health check."
  type        = string
  default     = "/"

  validation {
    condition     = startswith(var.health_check_path, "/")
    error_message = "health_check_path must start with /."
  }
}

variable "health_check_matcher" {
  description = "HTTP codes that mark a target healthy, e.g. 200 or 200-299."
  type        = string
  default     = "200"
}

variable "health_check_interval" {
  description = "Seconds between health checks."
  type        = number
  default     = 10

  validation {
    condition     = var.health_check_interval >= 5 && var.health_check_interval <= 300 && floor(var.health_check_interval) == var.health_check_interval
    error_message = "health_check_interval must be a whole number between 5 and 300."
  }
}

variable "health_check_timeout" {
  description = "Seconds without a response that count as a failed health check. Must be less than the interval."
  type        = number
  default     = 5

  validation {
    condition     = var.health_check_timeout >= 2 && var.health_check_timeout <= 120 && var.health_check_timeout < var.health_check_interval
    error_message = "health_check_timeout must be between 2 and 120 seconds and less than health_check_interval."
  }
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successes before a target is healthy."
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_healthy_threshold >= 2 && var.health_check_healthy_threshold <= 10 && floor(var.health_check_healthy_threshold) == var.health_check_healthy_threshold
    error_message = "health_check_healthy_threshold must be a whole number between 2 and 10."
  }
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failures before a target is unhealthy."
  type        = number
  default     = 2

  validation {
    condition     = var.health_check_unhealthy_threshold >= 2 && var.health_check_unhealthy_threshold <= 10 && floor(var.health_check_unhealthy_threshold) == var.health_check_unhealthy_threshold
    error_message = "health_check_unhealthy_threshold must be a whole number between 2 and 10."
  }
}
