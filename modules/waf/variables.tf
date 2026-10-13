variable "name_prefix" {
  description = "Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1."
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer the web ACL protects."
  type        = string
}

variable "default_action" {
  description = "Action for requests that match no rule."
  type        = string
  default     = "allow"
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
}

variable "managed_rule_action" {
  description = "count: rule groups only count matches (nothing is blocked). none: rule groups apply their own actions (block)."
  type        = string
  default     = "count"
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
}

variable "log_group_kms_key_arn" {
  description = "KMS key ARN to encrypt the WAF log group. null uses CloudWatch Logs default encryption."
  type        = string
  default     = null
}
