variable "project" {
  description = "Project name, used for the `project` tag."
  type        = string
  default     = "attendance-service"
}

variable "env" {
  description = "Environment name, used in the domain name and the `env` tag."
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

variable "region" {
  description = "Provider region. Must be us-east-1: Route 53 health check metrics (and their alarms) only exist there."
  type        = string
  default     = "us-east-1"
}

variable "base_domain" {
  description = "Base domain the service lives under, e.g. example.com. Required when enable_dns_records is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_dns_records || var.base_domain != null
    error_message = "base_domain is required when enable_dns_records is true."
  }
}

variable "enable_dns_records" {
  description = "Create the latency-routed records, Route 53 health checks and health check alarms. The dashboard is controlled separately by enable_dashboard."
  type        = bool
  default     = true
}

variable "service_subdomain" {
  description = "Subdomain label of the service under base_domain. The env domain is <env>.<service_subdomain>.<base_domain>."
  type        = string
  default     = "attendance"
}

variable "regions" {
  description = "Regional stacks to route to and chart, with the name_prefix each used."
  type = list(object({
    region      = string
    name_prefix = string
  }))
  default = [
    { region = "us-east-1", name_prefix = "attendance-service-dev-use1" },
    { region = "us-east-2", name_prefix = "attendance-service-dev-use2" },
  ]
}

variable "enable_health_checks" {
  description = "Create Route 53 health checks for each region's ALB."
  type        = bool
  default     = true
}

variable "enable_health_check_alarms" {
  description = "Create a CloudWatch alarm per health check."
  type        = bool
  default     = true
}

variable "enable_sns" {
  description = "Send health check alarms to the us-east-1 SNS topic. Set false when the regional stacks use enable_sns = false (the topic then does not exist)."
  type        = bool
  default     = true
}

variable "alarm_topic_name" {
  description = "Existing us-east-1 SNS topic (from the us-east-1 observability module) that health check alarms notify."
  type        = string
  default     = "attendance-service-dev-use1-alarms"
}

variable "enable_dashboard" {
  description = "Create the cross-region CloudWatch dashboard."
  type        = bool
  default     = true
}

variable "dashboard_name" {
  description = "Name of the cross-region CloudWatch dashboard."
  type        = string
  default     = "attendance-service-dev"
}
