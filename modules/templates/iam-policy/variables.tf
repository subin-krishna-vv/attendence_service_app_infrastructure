variable "name" {
  description = "Full policy name, e.g. attendance-service-dev-use1-dax-dynamodb."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9+=,.@_-]{1,128}$", var.name))
    error_message = "name must be 1-128 characters of A-Z, a-z, 0-9 or +=,.@_-."
  }
}

variable "description" {
  description = "What the policy grants and why."
  type        = string

  validation {
    condition     = length(trimspace(var.description)) > 0
    error_message = "description must not be empty."
  }
}

variable "policy_json" {
  description = "IAM policy document as JSON (e.g. from data.aws_iam_policy_document.*.json or jsonencode)."
  type        = string

  validation {
    condition     = can(jsondecode(var.policy_json))
    error_message = "policy_json must be valid JSON."
  }
}
