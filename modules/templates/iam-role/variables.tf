variable "name" {
  description = "Full role name, e.g. attendance-service-dev-use1-ecs-task."
  type        = string
}

variable "description" {
  description = "What the role is for."
  type        = string
}

variable "trusted_services" {
  description = "AWS service principals allowed to assume the role, e.g. [\"ecs-tasks.amazonaws.com\"]."
  type        = list(string)

  validation {
    condition     = alltrue([for s in var.trusted_services : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com$", s))])
    error_message = "trusted_services must be AWS service principals."
  }
}

variable "policy_arns" {
  description = "Managed policies to attach, keyed by a static name (keys must be known at plan time), e.g. { dynamodb = module.dax_policy.arn }."
  type        = map(string)
  default     = {}
}

variable "enable_source_account_condition" {
  description = "Add an aws:SourceAccount condition to the trust policy (confused-deputy protection). Turn off only for services that do not send aws:SourceAccount."
  type        = bool
  default     = true
}

variable "path" {
  description = "IAM path for the role."
  type        = string
  default     = "/"
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for credentials issued for this role."
  type        = number
  default     = 3600
}
