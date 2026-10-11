variable "project" {
  description = "Project name, used as the naming prefix and the `project` tag."
  type        = string
  default     = "attendance-service"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.project))
    error_message = "project must be lowercase alphanumeric with hyphens (S3 bucket naming rules)."
  }
}

variable "env" {
  description = "Environment name, used in the bucket name and the `env` tag."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owning team, used for the `owner` tag."
  type        = string
  default     = "devops-team"
}

variable "region" {
  description = "AWS region for the state bucket. Holds state for every stack in the environment."
  type        = string
  default     = "us-east-1"
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep noncurrent (previous) state file versions before they expire."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days > 0 && floor(var.noncurrent_version_expiration_days) == var.noncurrent_version_expiration_days
    error_message = "noncurrent_version_expiration_days must be a positive whole number."
  }
}
