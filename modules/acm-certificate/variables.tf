variable "domain_name" {
  description = "Domain the certificate is issued for, e.g. dev.attendance.example.com. Must be the zone name or inside it."
  type        = string

  validation {
    condition     = var.domain_name == var.zone_name || endswith(var.domain_name, ".${var.zone_name}")
    error_message = "domain_name must be zone_name or inside it."
  }
}

variable "zone_name" {
  description = "Name of the existing public Route 53 hosted zone used for DNS validation, e.g. dev.attendance.example.com."
  type        = string
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
}

variable "validation_record_ttl" {
  description = "TTL in seconds of the DNS validation records."
  type        = number
  default     = 60
}
