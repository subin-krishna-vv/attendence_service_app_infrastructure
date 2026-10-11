mock_provider "aws" {}

override_resource {
  target          = aws_sns_topic.alarms
  override_during = plan
  values = {
    arn = "arn:aws:sns:us-east-1:123456789012:attendance-service-dev-use1-alarms"
  }
}

variables {
  name_prefix             = "attendance-service-dev-use1"
  alb_arn_suffix          = "app/attendance-service-dev-use1-alb/0123456789abcdef"
  target_group_arn_suffix = "targetgroup/attendance-service-dev-use1-tg/0123456789abcdef"
  ecs_cluster_name        = "attendance-service-dev-use1-cluster"
  ecs_service_name        = "attendance-service-dev-use1-nginx"
  alarm_emails            = ["alerts@example.com", "oncall@example.com"]
}

run "alarm_topic_with_one_subscription_per_email" {
  command = plan

  assert {
    condition     = aws_sns_topic.alarms.name == "attendance-service-dev-use1-alarms"
    error_message = "Alarm topic must be named <name_prefix>-alarms."
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 2
    error_message = "Expected one email subscription per address."
  }

  assert {
    condition     = alltrue([for s in aws_sns_topic_subscription.email : s.protocol == "email"])
    error_message = "Subscriptions must use the email protocol."
  }
}

run "no_subscriptions_without_emails" {
  command = plan

  variables {
    alarm_emails = []
  }

  assert {
    condition     = length(aws_sns_topic_subscription.email) == 0
    error_message = "No subscriptions when alarm_emails is empty."
  }
}

run "error_rate_alarm_matches_success_slo" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.error_rate[0].threshold == 0.01 && aws_cloudwatch_metric_alarm.error_rate[0].comparison_operator == "GreaterThanThreshold"
    error_message = "Error-rate alarm must fire above the 0.01% error budget (99.99% success SLO)."
  }

  assert {
    condition = one([
      for q in aws_cloudwatch_metric_alarm.error_rate[0].metric_query : q.expression if q.id == "error_rate"
    ]) == "IF(requests >= 1000, 100 * (FILL(elb_5xx, 0) + FILL(target_5xx, 0)) / requests, 0)"
    error_message = "Error rate must be (ELB 5xx + target 5xx) / requests, only with >= 1000 requests."
  }

  assert {
    condition = toset([
      for q in aws_cloudwatch_metric_alarm.error_rate[0].metric_query : q.metric[0].metric_name if length(q.metric) > 0
    ]) == toset(["RequestCount", "HTTPCode_ELB_5XX_Count", "HTTPCode_Target_5XX_Count"])
    error_message = "Error rate must use RequestCount, HTTPCode_ELB_5XX_Count and HTTPCode_Target_5XX_Count."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.error_rate[0].alarm_actions == toset(["arn:aws:sns:us-east-1:123456789012:attendance-service-dev-use1-alarms"])
    error_message = "Error-rate alarm must notify the alarm topic."
  }
}

run "latency_alarm_matches_latency_slo" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.latency[0].metric_name == "TargetResponseTime" &&
      aws_cloudwatch_metric_alarm.latency[0].extended_statistic == "p99.99" &&
      aws_cloudwatch_metric_alarm.latency[0].threshold == 0.3
    )
    error_message = "Latency alarm must watch p99.99 TargetResponseTime against 300 ms."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.latency[0].evaluation_periods == 3 && aws_cloudwatch_metric_alarm.latency[0].datapoints_to_alarm == 3 && aws_cloudwatch_metric_alarm.latency[0].period == 60
    error_message = "Latency alarm must need 3 of 3 one-minute periods."
  }
}

run "supporting_alarms" {
  command = plan

  assert {
    condition     = aws_cloudwatch_metric_alarm.unhealthy_hosts[0].metric_name == "UnHealthyHostCount" && aws_cloudwatch_metric_alarm.unhealthy_hosts[0].threshold == 0
    error_message = "Unhealthy-targets alarm must fire on any unhealthy target."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.running_tasks[0].comparison_operator == "LessThanThreshold" && aws_cloudwatch_metric_alarm.running_tasks[0].threshold == 3
    error_message = "Running-tasks alarm must fire below 3 tasks."
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.cpu_high[0].threshold == 80 && aws_cloudwatch_metric_alarm.memory_high[0].threshold == 80
    error_message = "CPU and memory alarms must fire above 80%."
  }

  assert {
    condition     = length(output.alarm_names) == 6
    error_message = "Expected 6 alarms."
  }
}

run "alarms_off" {
  command = plan

  variables {
    enable_alarms = false
  }

  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.error_rate) == 0 &&
      length(aws_cloudwatch_metric_alarm.latency) == 0 &&
      length(aws_cloudwatch_metric_alarm.unhealthy_hosts) == 0 &&
      length(aws_cloudwatch_metric_alarm.running_tasks) == 0 &&
      length(aws_cloudwatch_metric_alarm.cpu_high) == 0 &&
      length(aws_cloudwatch_metric_alarm.memory_high) == 0
    )
    error_message = "No alarms when enable_alarms is false."
  }

  assert {
    condition     = length(output.alarm_names) == 0
    error_message = "alarm_names must be empty when alarms are disabled."
  }
}

run "rejects_invalid_email" {
  command = plan

  variables {
    alarm_emails = ["not-an-email"]
  }

  expect_failures = [var.alarm_emails]
}

run "rejects_invalid_percentile" {
  command = plan

  variables {
    latency_percentile = "99.99"
  }

  expect_failures = [var.latency_percentile]
}
