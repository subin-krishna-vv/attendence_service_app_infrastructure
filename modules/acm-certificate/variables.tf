variable "domain_name" {
  description = "Domain the certificate is issued for, e.g. dev.attendance.example.com. Must be the zone name or inside it."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.domain_name))
    error_message = "domain_name must be a lowercase fully qualified domain name without a trailing dot."
  }

  validation {
    condition     = var.domain_name == var.zone_name || endswith(var.domain_name, ".${var.zone_name}")
    error_message = "domain_name must be zone_name or a subdomain of it."
  }
}

variable "zone_name" {
  description = "Name of the existing public Route 53 hosted zone used for DNS validation, e.g. dev.attendance.example.com."
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\\.)+[a-z]{2,63}$", var.zone_name))
    error_message = "zone_name must be a lowercase fully qualified domain name without a trailing dot."
  }
}

variable "enable_wildcard" {
  description = "Also cover *.<domain_name> as a subject alternative name."
  type        = bool
  default     = true
}

variable "key_algorithm" {
  description = "Certificate key algorithm."
  type        = string
  default     = "RSA_2048"

  validation {
    condition     = contains(["RSA_2048", "EC_prime256v1", "EC_secp384r1"], var.key_algorithm)
    error_message = "key_algorithm must be RSA_2048, EC_prime256v1 or EC_secp384r1."
  }
}

variable "validation_record_ttl" {
  description = "TTL in seconds of the DNS validation records."
  type        = number
  default     = 60

  validation {
    condition     = var.validation_record_ttl >= 30 && var.validation_record_ttl <= 86400
    error_message = "validation_record_ttl must be between 30 and 86400 seconds."
  }
}
