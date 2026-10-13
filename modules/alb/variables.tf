variable "name_prefix" {
  description = "Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1. ALB and target group names are limited to 32 characters."
  type        = string

  validation {
    condition     = length(var.name_prefix) <= 28
    error_message = "name_prefix must be 28 characters or less (ALB names max 32)."
  }
}

variable "company" {
  description = "Company name, used as the access-log bucket name suffix to keep it globally unique."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC for the target group and security group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ) the ALB is placed in."
  type        = list(string)
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
}

variable "log_noncurrent_version_expiration_days" {
  description = "Days to keep overwritten (noncurrent) access-log object versions."
  type        = number
  default     = 1
}

variable "log_abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads to the log bucket are aborted."
  type        = number
  default     = 7
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
}

variable "http_port" {
  description = "HTTP listener port."
  type        = number
  default     = 80
}

variable "https_port" {
  description = "HTTPS listener port."
  type        = number
  default     = 443
}

variable "ssl_policy" {
  description = "Security policy of the HTTPS listener."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"

  validation {
    condition     = startswith(var.ssl_policy, "ELBSecurityPolicy-TLS13-")
    error_message = "ssl_policy must be a TLS 1.3 policy."
  }
}

variable "redirect_status_code" {
  description = "Status code of the HTTP to HTTPS redirect."
  type        = string
  default     = "HTTP_301"
}

variable "idle_timeout" {
  description = "Seconds a connection may be idle before the ALB closes it."
  type        = number
  default     = 60
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
}

variable "target_port" {
  description = "Port the targets (nginx containers) listen on."
  type        = number
  default     = 80
}

variable "target_protocol" {
  description = "Protocol from the ALB to the targets and for health checks."
  type        = string
  default     = "HTTP"
}

variable "deregistration_delay" {
  description = "Seconds the ALB keeps sending in-flight requests to a deregistering target."
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Path of the target health check."
  type        = string
  default     = "/"
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
}

variable "health_check_timeout" {
  description = "Seconds without a response that count as a failed health check. Must be less than the interval."
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Consecutive successes before a target is healthy."
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive failures before a target is unhealthy."
  type        = number
  default     = 2
}
