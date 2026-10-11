variable "domain_name" {
  description = "Fully qualified domain name of the public hosted zone, e.g. dev.attendance.example.com (no trailing dot)."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase fully qualified domain name without a trailing dot."
  }
}

variable "comment" {
  description = "Zone comment. Defaults to \"Public zone for <domain_name>\" when null."
  type        = string
  default     = null
}

variable "force_destroy" {
  description = "Delete all records (including ones Terraform does not manage) when the zone is destroyed. Keep false."
  type        = bool
  default     = false
}
