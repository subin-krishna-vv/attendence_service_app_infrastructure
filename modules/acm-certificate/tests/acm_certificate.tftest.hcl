mock_provider "aws" {
  mock_data "aws_route53_zone" {
    defaults = {
      zone_id = "Z0123456789ABCDEFGHIJ"
    }
  }
}

variables {
  domain_name = "dev.attendance.example.com"
  zone_name   = "dev.attendance.example.com"
}

run "certificate_with_wildcard_by_default" {
  command = plan

  override_resource {
    target          = aws_acm_certificate.this
    override_during = plan
    values = {
      domain_validation_options = [
        {
          domain_name           = "dev.attendance.example.com"
          resource_record_name  = "_abc.dev.attendance.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_xyz.acm-validations.aws."
        },
        {
          domain_name           = "*.dev.attendance.example.com"
          resource_record_name  = "_abc.dev.attendance.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_xyz.acm-validations.aws."
        },
      ]
    }
  }

  assert {
    condition     = aws_acm_certificate.this.domain_name == "dev.attendance.example.com"
    error_message = "Certificate must be issued for domain_name."
  }

  assert {
    condition     = aws_acm_certificate.this.subject_alternative_names == toset(["*.dev.attendance.example.com"])
    error_message = "Certificate must include the wildcard SAN by default."
  }

  assert {
    condition     = aws_acm_certificate.this.validation_method == "DNS" && aws_acm_certificate.this.key_algorithm == "RSA_2048"
    error_message = "Certificate must use DNS validation and RSA 2048."
  }

  assert {
    condition     = length(aws_route53_record.validation) == 2
    error_message = "Expected one validation record per certificate name (apex and wildcard)."
  }

  assert {
    condition = alltrue([
      for r in aws_route53_record.validation :
      r.zone_id == "Z0123456789ABCDEFGHIJ" && r.allow_overwrite && r.ttl == 60 && r.type == "CNAME"
    ])
    error_message = "Validation records must be CNAMEs in the looked-up zone, with allow_overwrite and a 60 s TTL."
  }
}

run "wildcard_off" {
  command = plan

  variables {
    enable_wildcard = false
  }

  override_resource {
    target          = aws_acm_certificate.this
    override_during = plan
    values = {
      domain_validation_options = [
        {
          domain_name           = "dev.attendance.example.com"
          resource_record_name  = "_abc.dev.attendance.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_xyz.acm-validations.aws."
        },
      ]
    }
  }

  assert {
    condition     = length(aws_acm_certificate.this.subject_alternative_names) == 0
    error_message = "No SANs when enable_wildcard is false."
  }

  assert {
    condition     = length(aws_route53_record.validation) == 1
    error_message = "Expected a single validation record without the wildcard."
  }
}

run "rejects_domain_outside_zone" {
  command = plan

  variables {
    domain_name = "dev.attendance.other.com"
  }

  expect_failures = [var.domain_name]
}

run "rejects_suffix_lookalike_domain" {
  command = plan

  variables {
    domain_name = "xdev.attendance.example.com"
  }

  expect_failures = [var.domain_name]
}

run "rejects_uppercase_zone" {
  command = plan

  variables {
    zone_name   = "Dev.Attendance.Example.com"
    domain_name = "dev.attendance.example.com"
  }

  expect_failures = [var.zone_name]
}
