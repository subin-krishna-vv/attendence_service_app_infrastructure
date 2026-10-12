# templates/security-group

Creates one **security group** with explicit inbound rules and allow-all outbound. Per the repo rules, this is the only module allowed to declare `aws_security_group`.

## Resources

- `aws_security_group.this`
- `aws_vpc_security_group_ingress_rule.this`: one per entry in `ingress_rules`
- `aws_vpc_security_group_egress_rule.all`: all protocols to `0.0.0.0/0`

The module uses the per-rule resources (`aws_vpc_security_group_*_rule`) rather than inline `ingress`/`egress` blocks. Each rule is then its own resource, with its own description, and changing one rule doesn't rewrite the others.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | — (required) | Full security group name, e.g. attendance-service-dev-use1-alb. |
| `description` | string | — (required) | What the security group protects. Changing it replaces the group. |
| `vpc_id` | string | — (required) | ID of the VPC the security group belongs to. |
| `ingress_rules` | map(object) | `{}` | Inbound rules keyed by a static name. Each rule needs a description and exactly one source: referenced_security_group_id (preferred) or cidr_ipv4. ip_protocol is tcp (default) or udp. |
| `egress_cidr_ipv4` | string | `"0.0.0.0/0"` | IPv4 CIDR all outbound traffic is allowed to. |

## Outputs

| Name | Description |
| --- | --- |
| `id` | Security group ID |
| `arn` | Security group ARN |
| `name` | Security group name |

## Toggles

None. Callers switch the whole module with `count` on the module block.

## Example

```hcl
module "ecs_task_sg" {
  source      = "../templates/security-group"
  name        = "attendance-service-dev-use1-ecs-task"
  description = "ECS tasks: HTTP from the ALB only"
  vpc_id      = module.vpc.vpc_id
  ingress_rules = {
    http_from_alb = {
      description                  = "HTTP from ALB"
      from_port                    = 80
      to_port                      = 80
      referenced_security_group_id = module.alb_sg.id
    }
  }
}
```

## Design notes

- **Allow-all egress.** A deliberate decision. Inbound rules are the control point, and the tasks need outbound access to Docker Hub through NAT.
- **Not attached here (CKV2_AWS_5).** This is a template; the caller attaches the group.
- IPv4 only, matching the VPC design.
