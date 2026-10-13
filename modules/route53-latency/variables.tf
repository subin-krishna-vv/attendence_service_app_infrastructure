variable "zone_name" {
  description = "Name of the existing public hosted zone, e.g. dev.attendance.example.com."
  type        = string
}

variable "record_name" {
  description = "Record users resolve, e.g. dev.attendance.example.com. Must be zone_name or inside it."
  type        = string

  validation {
    condition     = var.record_name == var.zone_name || endswith(var.record_name, ".${var.zone_name}")
    error_message = "record_name must be zone_name or inside it."
  }
}

variable "regions" {
  description = "Regions to route to, each with the name_prefix its regional stack used (e.g. attendance-service-dev-use1)."
  type = list(object({
    region      = string
    name_prefix = string
  }))
}

variable "alb_name_suffix" {
  description = "Suffix the alb module appends to name_prefix for the ALB name."
  type        = string
  default     = "-alb"
}

variable "evaluate_target_health" {
  description = "Let Route 53 also use the ALB's own target health when answering queries."
  type        = bool
  default     = true
}

variable "enable_health_checks" {
  description = "Create a Route 53 health check per region and attach it to that region's record."
  type        = bool
  default     = true
}

variable "health_check_type" {
  description = "Protocol of the health checks."
  type        = string
  default     = "HTTPS"
}

variable "health_check_port" {
  description = "Port the health checks connect to."
  type        = number
  default     = 443
}

variable "health_check_path" {
  description = "Path the health checks request."
  type        = string
  default     = "/"
}

variable "health_check_request_interval" {
  description = "Seconds between checks from each checker: 10 (fast, extra cost) or 30."
  type        = number
  default     = 10
}

variable "health_check_failure_threshold" {
  description = "Consecutive failures before an endpoint is unhealthy."
  type        = number
  default     = 3
}

variable "health_check_measure_latency" {
  description = "Publish Route 53 checker latency metrics (extra cost)."
  type        = bool
  default     = false
}

variable "health_check_regions" {
  description = "Route 53 checker regions (at least 3). null uses all checker regions."
  type        = list(string)
  default     = null
}

variable "enable_health_check_alarms" {
  description = "Create a CloudWatch alarm per health check. Route 53 health check metrics only exist in us-east-1, so the provider must be us-east-1."
  type        = bool
  default     = true
}

variable "alarm_topic_name" {
  description = "Name of an existing SNS topic in the provider region that health check alarms notify (e.g. attendance-service-dev-use1-alarms). null creates the alarms without notifications."
  type        = string
  default     = null
}

variable "alarm_period" {
  description = "Seconds per evaluation period of the health check alarms."
  type        = number
  default     = 60
}

variable "alarm_evaluation_periods" {
  description = "Periods a health check must be unhealthy before its alarm fires."
  type        = number
  default     = 1
}
