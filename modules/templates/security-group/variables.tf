variable "name" {
  description = "Full security group name, e.g. attendance-service-dev-use1-alb."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 255 && !startswith(lower(var.name), "sg-")
    error_message = "name must be 1-255 characters and must not start with sg-."
  }
}

variable "description" {
  description = "What the security group protects. Changing it replaces the group."
  type        = string

  validation {
    condition     = length(trimspace(var.description)) > 0
    error_message = "description must not be empty."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the security group belongs to."
  type        = string
}

variable "ingress_rules" {
  description = <<-EOT
    Inbound rules keyed by a static name. Each rule needs a description and exactly one source:
    referenced_security_group_id (preferred) or cidr_ipv4. ip_protocol is tcp (default) or udp.
  EOT
  type = map(object({
    description                  = string
    from_port                    = number
    to_port                      = number
    ip_protocol                  = optional(string, "tcp")
    referenced_security_group_id = optional(string)
    cidr_ipv4                    = optional(string)
  }))
  default = {}

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : (r.referenced_security_group_id == null) != (r.cidr_ipv4 == null)])
    error_message = "Each ingress rule must set exactly one of referenced_security_group_id or cidr_ipv4."
  }

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : length(trimspace(r.description)) > 0])
    error_message = "Each ingress rule must have a non-empty description."
  }

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : contains(["tcp", "udp"], r.ip_protocol)])
    error_message = "ip_protocol must be tcp or udp (all-protocol ingress is not allowed)."
  }

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : r.from_port >= 0 && r.to_port <= 65535 && r.from_port <= r.to_port])
    error_message = "Ports must be within 0-65535 and from_port must be <= to_port."
  }
}
