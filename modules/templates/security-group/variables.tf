variable "name" {
  description = "Full security group name, e.g. attendance-service-dev-use1-alb."
  type        = string
}

variable "description" {
  description = "What the security group protects. Changing it replaces the group."
  type        = string
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
    error_message = "Each ingress rule needs exactly one source."
  }

  validation {
    condition     = alltrue([for r in values(var.ingress_rules) : contains(["tcp", "udp"], r.ip_protocol)])
    error_message = "Ingress rules must use tcp or udp."
  }
}

variable "egress_cidr_ipv4" {
  description = "IPv4 CIDR all outbound traffic is allowed to."
  type        = string
  default     = "0.0.0.0/0"
}
