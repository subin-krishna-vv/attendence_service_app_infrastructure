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

variable "company" {
  description = "Company name, used as the state bucket name suffix to keep it globally unique."
  type        = string
  default     = "abc"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.company))
    error_message = "company must be lowercase alphanumeric with hyphens (S3 bucket naming rules)."
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

variable "force_destroy" {
  description = "Allow Terraform to delete the state bucket even when it holds objects. Keep false."
  type        = bool
  default     = false
}

variable "enable_versioning" {
  description = "Keep previous versions of every state file (needed to roll back a bad apply)."
  type        = bool
  default     = true
}

variable "sse_algorithm" {
  description = "Default server-side encryption: AES256 (SSE-S3) or aws:kms (SSE-KMS with the AWS-managed aws/s3 key)."
  type        = string
  default     = "AES256"

  validation {
    condition     = contains(["AES256", "aws:kms"], var.sse_algorithm)
    error_message = "sse_algorithm must be AES256 or aws:kms."
  }
}

variable "object_ownership" {
  description = "S3 Object Ownership setting. BucketOwnerEnforced disables ACLs."
  type        = string
  default     = "BucketOwnerEnforced"

  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "object_ownership must be BucketOwnerEnforced, BucketOwnerPreferred or ObjectWriter."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads are aborted."
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_upload_days > 0 && floor(var.abort_incomplete_multipart_upload_days) == var.abort_incomplete_multipart_upload_days
    error_message = "abort_incomplete_multipart_upload_days must be a positive whole number."
  }
}

variable "block_public_access" {
  description = "Turn on all four S3 Block Public Access settings for the bucket."
  type        = bool
  default     = true
}
