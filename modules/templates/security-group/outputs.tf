output "id" {
  description = "ID of the security group, for attaching it or referencing it from another group's rules."
  value       = aws_security_group.this.id
}

output "arn" {
  description = "ARN of the security group."
  value       = aws_security_group.this.arn
}

output "name" {
  description = "Name of the security group."
  value       = aws_security_group.this.name
}

output "ingress_rules" {
  description = "Created ingress rules keyed by rule name: ports, protocol and source."
  value = {
    for k, r in aws_vpc_security_group_ingress_rule.this : k => {
      from_port                    = r.from_port
      to_port                      = r.to_port
      ip_protocol                  = r.ip_protocol
      referenced_security_group_id = r.referenced_security_group_id
      cidr_ipv4                    = r.cidr_ipv4
    }
  }
}
