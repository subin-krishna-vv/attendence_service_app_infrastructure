variable "dashboard_name" {
  description = "Name of the CloudWatch dashboard, e.g. attendance-service-dev."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]{1,255}$", var.dashboard_name))
    error_message = "dashboard_name may contain only letters, digits, - and _ (max 255)."
  }
}

variable "regions" {
  description = "Regions to show side by side, each with the name_prefix its regional stack used (e.g. attendance-service-dev-use1)."
  type = list(object({
    region      = string
    name_prefix = string
  }))

  validation {
    condition     = length(var.regions) >= 1 && length(var.regions) <= 4
    error_message = "regions must contain between 1 and 4 entries."
  }

  validation {
    condition     = length(distinct([for r in var.regions : r.region])) == length(var.regions)
    error_message = "Each region may appear only once."
  }
}

variable "alb_name_suffix" {
  description = "Suffix the alb module appends to name_prefix for the ALB name."
  type        = string
  default     = "-alb"
}

variable "target_group_name_suffix" {
  description = "Suffix the alb module appends to name_prefix for the target group name."
  type        = string
  default     = "-tg"
}

variable "ecs_cluster_name_suffix" {
  description = "Suffix the ecs-service module appends to name_prefix for the cluster name."
  type        = string
  default     = "-cluster"
}

variable "ecs_service_name_suffix" {
  description = "Suffix the ecs-service module appends to name_prefix for the service name."
  type        = string
  default     = "-nginx"
}

variable "web_acl_name_suffix" {
  description = "Suffix the waf module appends to name_prefix for the web ACL name."
  type        = string
  default     = "-waf"
}

variable "include_waf_widget" {
  description = "Show WAF allowed and counted requests per region."
  type        = bool
  default     = true
}

variable "waf_rule_metric_names" {
  description = "Rule metric names to chart in the WAF widget (the waf module uses the rule group names)."
  type        = list(string)
  default = [
    "AWSManagedRulesCommonRuleSet",
    "AWSManagedRulesKnownBadInputsRuleSet",
    "AWSManagedRulesAmazonIpReputationList",
  ]
}

variable "success_slo_percent" {
  description = "Success SLO drawn as a horizontal line on the success-rate widget."
  type        = number
  default     = 99.99
}

variable "latency_threshold_seconds" {
  description = "Latency SLO threshold drawn as a horizontal line on the latency widget."
  type        = number
  default     = 0.3
}

variable "latency_percentiles" {
  description = "TargetResponseTime percentiles shown on the latency widget."
  type        = list(string)
  default     = ["p50", "p99", "p99.99"]
}

variable "period" {
  description = "Default metric period in seconds for all widgets."
  type        = number
  default     = 60

  validation {
    condition     = contains([60, 300, 900, 3600], var.period)
    error_message = "period must be 60, 300, 900 or 3600."
  }
}

variable "widget_height" {
  description = "Height of each metric widget in grid units."
  type        = number
  default     = 6
}
