mock_provider "aws" {}

variables {
  name        = "attendance-service-dev-use1-ecs-task"
  description = "Test security group"
  vpc_id      = "vpc-0123456789abcdef0"
}

run "no_ingress_by_default_and_allow_all_egress" {
  command = plan

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "No ingress rules may exist unless ingress_rules is set."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.all.ip_protocol == "-1" && aws_vpc_security_group_egress_rule.all.cidr_ipv4 == "0.0.0.0/0"
    error_message = "Egress must allow all outbound traffic."
  }

  assert {
    condition     = aws_security_group.this.vpc_id == "vpc-0123456789abcdef0"
    error_message = "Security group must be created in the given VPC."
  }
}

run "ingress_from_security_group_source" {
  command = plan

  variables {
    ingress_rules = {
      http_from_alb = {
        description                  = "HTTP from ALB"
        from_port                    = 80
        to_port                      = 80
        referenced_security_group_id = "sg-0aaaaaaaaaaaaaaaa"
      }
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["http_from_alb"].referenced_security_group_id == "sg-0aaaaaaaaaaaaaaaa"
    error_message = "Rule must reference the given security group."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["http_from_alb"].cidr_ipv4 == null
    error_message = "A security-group-sourced rule must not also open a CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["http_from_alb"].ip_protocol == "tcp"
    error_message = "ip_protocol must default to tcp."
  }
}

run "ingress_from_cidr_source" {
  command = plan

  variables {
    ingress_rules = {
      https_from_internet = {
        description = "HTTPS from the internet"
        from_port   = 443
        to_port     = 443
        cidr_ipv4   = "0.0.0.0/0"
      }
    }
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["https_from_internet"].cidr_ipv4 == "0.0.0.0/0"
    error_message = "Rule must use the given CIDR."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["https_from_internet"].referenced_security_group_id == null
    error_message = "A CIDR-sourced rule must not also reference a security group."
  }
}

run "rejects_rule_with_both_sources" {
  command = plan

  variables {
    ingress_rules = {
      bad = {
        description                  = "Both sources"
        from_port                    = 80
        to_port                      = 80
        referenced_security_group_id = "sg-0aaaaaaaaaaaaaaaa"
        cidr_ipv4                    = "10.10.0.0/16"
      }
    }
  }

  expect_failures = [var.ingress_rules]
}

run "rejects_rule_with_no_source" {
  command = plan

  variables {
    ingress_rules = {
      bad = {
        description = "No source"
        from_port   = 80
        to_port     = 80
      }
    }
  }

  expect_failures = [var.ingress_rules]
}

run "rejects_all_protocol_ingress" {
  command = plan

  variables {
    ingress_rules = {
      bad = {
        description = "All protocols"
        from_port   = 0
        to_port     = 0
        ip_protocol = "-1"
        cidr_ipv4   = "10.10.0.0/16"
      }
    }
  }

  expect_failures = [var.ingress_rules]
}

run "rejects_empty_rule_description" {
  command = plan

  variables {
    ingress_rules = {
      bad = {
        description = ""
        from_port   = 80
        to_port     = 80
        cidr_ipv4   = "10.10.0.0/16"
      }
    }
  }

  expect_failures = [var.ingress_rules]
}

run "overrides_egress_cidr" {
  command = plan

  variables {
    egress_cidr_ipv4 = "10.10.0.0/16"
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.all.cidr_ipv4 == "10.10.0.0/16"
    error_message = "Egress CIDR must follow the variable."
  }
}

run "rejects_invalid_egress_cidr" {
  command = plan

  variables {
    egress_cidr_ipv4 = "not-a-cidr"
  }

  expect_failures = [var.egress_cidr_ipv4]
}
