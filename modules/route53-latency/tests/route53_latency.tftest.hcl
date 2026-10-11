mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_route53_zone" {
    defaults = {
      zone_id = "Z0123456789ABCDEFGHIJ"
    }
  }

  mock_data "aws_lb" {
    defaults = {
      dns_name = "attendance-service-dev-alb-123456789.us-east-1.elb.amazonaws.com"
      zone_id  = "Z35SXDOTRQ7X7K"
    }
  }

  mock_data "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:attendance-service-dev-use1-alarms"
    }
  }
}

override_resource {
  target          = aws_route53_health_check.this
  override_during = plan
  values = {
    id = "hc-0123456789"
  }
}

variables {
  zone_name   = "dev.attendance.example.com"
  record_name = "dev.attendance.example.com"
  regions = [
    { region = "us-east-1", name_prefix = "attendance-service-dev-use1" },
    { region = "us-east-2", name_prefix = "attendance-service-dev-use2" },
  ]
  alarm_topic_name = "attendance-service-dev-use1-alarms"
}

run "https_health_check_per_region" {
  command = plan

  assert {
    condition     = length(aws_route53_health_check.this) == 2
    error_message = "Expected one health check per region."
  }

  assert {
    condition = alltrue([
      for hc in aws_route53_health_check.this :
      hc.type == "HTTPS" && hc.port == 443 && hc.resource_path == "/" && hc.request_interval == 10 && hc.failure_threshold == 3 && hc.enable_sni
    ])
    error_message = "Health checks must be HTTPS on 443, path /, every 10 s, failing after 3."
  }

  assert {
    condition     = aws_route53_health_check.this["us-east-2"].fqdn == data.aws_lb.this["us-east-2"].dns_name
    error_message = "Each health check must target its region's ALB DNS name."
  }
}

run "latency_alias_record_per_region" {
  command = plan

  assert {
    condition     = length(aws_route53_record.this) == 2
    error_message = "Expected one latency record per region."
  }

  assert {
    condition = alltrue([
      for k, r in aws_route53_record.this :
      r.name == "dev.attendance.example.com" && r.type == "A" && r.set_identifier == k && one(r.latency_routing_policy).region == k
    ])
    error_message = "Each record must be an A record for the env domain with latency routing to its own region."
  }

  assert {
    condition = alltrue([
      for r in aws_route53_record.this :
      one(r.alias).evaluate_target_health && one(r.alias).zone_id == "Z35SXDOTRQ7X7K" && r.zone_id == "Z0123456789ABCDEFGHIJ"
    ])
    error_message = "Records must alias the ALB with evaluate_target_health in the looked-up zone."
  }

  assert {
    condition     = alltrue([for r in aws_route53_record.this : r.health_check_id == "hc-0123456789"])
    error_message = "Each record must be linked to a health check."
  }
}

run "health_check_alarms_in_us_east_1" {
  command = plan

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.health) == 2
    error_message = "Expected one alarm per health check."
  }

  assert {
    condition = alltrue([
      for a in aws_cloudwatch_metric_alarm.health :
      a.namespace == "AWS/Route53" && a.metric_name == "HealthCheckStatus" && a.comparison_operator == "LessThanThreshold" && a.threshold == 1
    ])
    error_message = "Alarms must fire when HealthCheckStatus drops below 1."
  }

  assert {
    condition     = alltrue([for a in aws_cloudwatch_metric_alarm.health : a.alarm_actions == toset(["arn:aws:sns:us-east-1:123456789012:attendance-service-dev-use1-alarms"])])
    error_message = "Alarms must notify the us-east-1 alarm topic."
  }
}

run "health_checks_off" {
  command = plan

  variables {
    enable_health_checks = false
    alarm_topic_name     = null
  }

  assert {
    condition     = length(aws_route53_health_check.this) == 0 && length(aws_cloudwatch_metric_alarm.health) == 0
    error_message = "No health checks or alarms when enable_health_checks is false."
  }

  assert {
    condition     = alltrue([for r in aws_route53_record.this : r.health_check_id == null])
    error_message = "Records must not reference health checks when they are disabled."
  }

  assert {
    condition     = length(aws_route53_record.this) == 2
    error_message = "Latency records must remain without health checks."
  }
}

run "alarms_off_keeps_health_checks" {
  command = plan

  variables {
    enable_health_check_alarms = false
    alarm_topic_name           = null
  }

  assert {
    condition     = length(aws_cloudwatch_metric_alarm.health) == 0 && length(aws_route53_health_check.this) == 2
    error_message = "Disabling alarms must keep the health checks."
  }
}

run "alarms_require_us_east_1" {
  command = plan

  override_data {
    target = data.aws_region.current
    values = {
      region = "us-east-2"
    }
  }

  expect_failures = [aws_cloudwatch_metric_alarm.health]
}

run "alarms_require_topic" {
  command = plan

  variables {
    alarm_topic_name = null
  }

  expect_failures = [var.alarm_topic_name]
}

run "rejects_record_outside_zone" {
  command = plan

  variables {
    record_name = "dev.attendance.other.com"
  }

  expect_failures = [var.record_name]
}
