variable "project" {
  description = "Project name, used for the `project` tag."
  type        = string
  default     = "attendance-service"
}

variable "env" {
  description = "Environment name, used in the domain name and the `env` tag."
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
  description = "Provider region for global resources."
  type        = string
  default     = "us-east-1"
}

variable "base_domain" {
  description = "Base domain the service lives under, e.g. example.com. The dev zone is dev.attendance.<base_domain>."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.base_domain))
    error_message = "base_domain must be a lowercase domain name without a trailing dot, e.g. example.com."
  }
}
