mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b", "us-east-1c", "us-east-1d"]
    }
  }

  mock_data "aws_route53_zone" {
    defaults = {
      zone_id = "Z0123456789ABCDEFGHIJ"
    }
  }

  mock_resource "aws_acm_certificate" {
    override_during = plan
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_acm_certificate_validation" {
    override_during = plan
    defaults = {
      certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_lb" {
    override_during = plan
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/attendance-service-dev-use1-alb/0123456789abcdef"
      arn_suffix = "app/attendance-service-dev-use1-alb/0123456789abcdef"
    }
  }

  mock_resource "aws_lb_target_group" {
    override_during = plan
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/attendance-service-dev-use1-tg/0123456789abcdef"
      arn_suffix = "targetgroup/attendance-service-dev-use1-tg/0123456789abcdef"
    }
  }

  mock_resource "aws_wafv2_web_acl" {
    override_during = plan
    defaults = {
      arn = "arn:aws:wafv2:us-east-1:123456789012:regional/webacl/attendance-service-dev-use1-waf/00000000-0000-0000-0000-000000000000"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    override_during = plan
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:mock"
    }
  }

  mock_resource "aws_sns_topic" {
    override_during = plan
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:attendance-service-dev-use1-alarms"
    }
  }

  mock_resource "aws_iam_policy" {
    override_during = plan
    defaults = {
      arn = "arn:aws:iam::123456789012:policy/mock"
    }
  }

  mock_resource "aws_iam_role" {
    override_during = plan
    defaults = {
      arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  mock_resource "aws_ecs_cluster" {
    override_during = plan
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:cluster/attendance-service-dev-use1-cluster"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    override_during = plan
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/attendance-service-dev-use1-nginx:1"
    }
  }

  mock_resource "aws_s3_bucket" {
    override_during = plan
    defaults = {
      arn = "arn:aws:s3:::attendance-service-dev-use1-alb-logs-abc"
    }
  }
}

override_resource {
  target          = module.certificate.aws_acm_certificate.this
  override_during = plan
  values = {
    arn = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
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

variables {
  base_domain  = "example.com"
  alarm_emails = ["alerts@example.com"]
}

run "stack_plans_with_defaults" {
  command = plan

  assert {
    condition     = output.name_prefix == "attendance-service-dev-use1"
    error_message = "name_prefix must be <project>-<env>-<region_short>."
  }

  assert {
    condition     = length(module.vpc.public_subnet_ids) == 3 && length(module.vpc.private_subnet_ids) == 3
    error_message = "The VPC must provide 3 public and 3 private subnets."
  }

  assert {
    condition     = module.certificate.domain_name == "dev.attendance.example.com"
    error_message = "The certificate must be issued for dev.attendance.<base_domain>."
  }

  assert {
    condition     = length(module.waf) == 1
    error_message = "WAF must be created by default."
  }

  assert {
    condition     = module.ecs_service.service_name == "attendance-service-dev-use1-nginx" && module.ecs_service.cluster_name == "attendance-service-dev-use1-cluster"
    error_message = "ECS names must follow the name prefix (global-dns relies on them)."
  }

  assert {
    condition     = length(module.observability.alarm_names) == 6
    error_message = "All 6 regional alarms must be created."
  }
}

run "waf_toggle_off" {
  command = plan

  variables {
    enable_waf = false
  }

  assert {
    condition     = length(module.waf) == 0 && output.web_acl_arn == null
    error_message = "No WAF when enable_waf is false."
  }
}

run "rejects_unknown_env" {
  command = plan

  variables {
    env = "qa"
  }

  expect_failures = [var.env]
}
