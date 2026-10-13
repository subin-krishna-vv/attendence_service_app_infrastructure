variable "project" {
  description = "Project name, used as the naming prefix and the `project` tag."
  type        = string
  default     = "attendance-service"
}

variable "env" {
  description = "Environment name, used in the bucket name and the `env` tag."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env must be dev, staging or prod."
  }
}

variable "company" {
  description = "Company name, used as the state bucket name suffix to keep it globally unique."
  type        = string
  default     = "abc"
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
}

variable "object_ownership" {
  description = "S3 Object Ownership setting. BucketOwnerEnforced disables ACLs."
  type        = string
  default     = "BucketOwnerEnforced"
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which incomplete multipart uploads are aborted."
  type        = number
  default     = 7
}

variable "block_public_access" {
  description = "Turn on all four S3 Block Public Access settings for the bucket."
  type        = bool
  default     = true
}
