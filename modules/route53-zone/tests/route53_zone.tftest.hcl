mock_provider "aws" {}

variables {
  domain_name = "dev.attendance.example.com"
}

run "creates_public_zone_for_domain" {
  command = plan

  assert {
    condition     = aws_route53_zone.this.name == "dev.attendance.example.com"
    error_message = "Zone must be created for the given domain name."
  }

  assert {
    condition     = length(aws_route53_zone.this.vpc) == 0
    error_message = "Zone must be public (no VPC association)."
  }

  assert {
    condition     = aws_route53_zone.this.force_destroy == false
    error_message = "force_destroy must be off so records are never deleted with the zone."
  }
}

run "rejects_trailing_dot" {
  command = plan

  variables {
    domain_name = "dev.attendance.example.com."
  }

  expect_failures = [var.domain_name]
}

run "rejects_uppercase" {
  command = plan

  variables {
    domain_name = "Dev.Attendance.Example.com"
  }

  expect_failures = [var.domain_name]
}

run "rejects_single_label" {
  command = plan

  variables {
    domain_name = "localhost"
  }

  expect_failures = [var.domain_name]
}

run "overrides_comment_and_force_destroy" {
  command = plan

  variables {
    comment       = "Dev zone"
    force_destroy = true
  }

  assert {
    condition     = aws_route53_zone.this.comment == "Dev zone" && aws_route53_zone.this.force_destroy == true
    error_message = "comment and force_destroy must follow the variables."
  }
}
