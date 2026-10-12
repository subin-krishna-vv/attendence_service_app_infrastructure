variable "name_prefix" {
  description = "Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name_prefix)) && length(var.name_prefix) <= 120
    error_message = "name_prefix must be lowercase alphanumeric with hyphens and at most 120 characters."
  }
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer the web ACL protects."
  type        = string
}

variable "default_action" {
  description = "Action for requests that match no rule."
  type        = string
  default     = "allow"

  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "default_action must be allow or block."
  }
}

variable "managed_rule_groups" {
  description = "AWS managed rule groups to evaluate, in priority order (lower runs first)."
  type = list(object({
    name        = string
    priority    = number
    vendor_name = optional(string, "AWS")
  }))
  default = [
    { name = "AWSManagedRulesCommonRuleSet", priority = 10 },
    { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 20 },
    { name = "AWSManagedRulesAmazonIpReputationList", priority = 30 },
  ]

  validation {
    condition     = length(var.managed_rule_groups) > 0
    error_message = "managed_rule_groups must contain at least one rule group."
  }

  validation {
    condition     = length(distinct([for g in var.managed_rule_groups : g.priority])) == length(var.managed_rule_groups)
    error_message = "Each managed rule group must have a unique priority."
  }
}

variable "managed_rule_action" {
  description = "count: rule groups only count matches (nothing is blocked). none: rule groups apply their own actions (block)."
  type        = string
  default     = "count"

  validation {
    condition     = contains(["count", "none"], var.managed_rule_action)
    error_message = "managed_rule_action must be count or none."
  }
}

variable "cloudwatch_metrics_enabled" {
  description = "Publish CloudWatch metrics for the web ACL and each rule group."
  type        = bool
  default     = true
}

variable "sampled_requests_enabled" {
  description = "Keep samples of requests matching each rule (viewable in the WAF console)."
  type        = bool
  default     = true
}

variable "enable_logging" {
  description = "Send full web ACL logs to a CloudWatch Logs log group."
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "Days to keep WAF logs in CloudWatch Logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs retention value (1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288 or 3653)."
  }
}

variable "log_group_kms_key_arn" {
  description = "KMS key ARN to encrypt the WAF log group. null uses CloudWatch Logs default encryption."
  type        = string
  default     = null
}
