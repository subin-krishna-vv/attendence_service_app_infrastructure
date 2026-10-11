variable "name" {
  description = "Full role name, e.g. attendance-service-dev-use1-ecs-task."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,64}$", var.name))
    error_message = "name must be 1-64 characters of A-Z, a-z, 0-9 or +=,.@_-."
  }
}

variable "description" {
  description = "What the role is for."
  type        = string

  validation {
    condition     = length(trimspace(var.description)) > 0
    error_message = "description must not be empty."
  }
}

variable "trusted_services" {
  description = "AWS service principals allowed to assume the role, e.g. [\"ecs-tasks.amazonaws.com\"]."
  type        = list(string)

  validation {
    condition     = length(var.trusted_services) > 0
    error_message = "trusted_services must contain at least one service principal."
  }

  validation {
    condition     = alltrue([for s in var.trusted_services : can(regex("^[a-z0-9.-]+\\.amazonaws\\.com$", s))])
    error_message = "Each trusted service must be an AWS service principal ending in .amazonaws.com."
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

  validation {
    condition     = can(regex("^/([A-Za-z0-9+=,.@_-]+/)*$", var.path))
    error_message = "path must start and end with / (e.g. / or /attendance-service/)."
  }
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for credentials issued for this role."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}
