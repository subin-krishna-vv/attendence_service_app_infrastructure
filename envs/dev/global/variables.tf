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
    error_message = "env must be dev, staging or prod."
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
  description = "Base domain the service lives under, e.g. example.com. The env zone is <env>.<service_subdomain>.<base_domain>. Required when enable_dns_zone is true."
  type        = string
  default     = null

  validation {
    condition     = !var.enable_dns_zone || var.base_domain != null
    error_message = "base_domain is required when enable_dns_zone is true."
  }
}

variable "enable_dns_zone" {
  description = "Create the env's public hosted zone. When false, the regional stacks must set enable_certificate = false and global-dns must set enable_dns_records = false."
  type        = bool
  default     = true
}

variable "service_subdomain" {
  description = "Subdomain label of the service under base_domain. The env zone is <env>.<service_subdomain>.<base_domain>."
  type        = string
  default     = "attendance"
}

variable "zone_comment" {
  description = "Hosted zone comment; null uses the module default."
  type        = string
  default     = null
}

variable "zone_force_destroy" {
  description = "Delete all records when the zone is destroyed. Keep false."
  type        = bool
  default     = false
}
