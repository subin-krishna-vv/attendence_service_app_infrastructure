locals {
  alarm_count = var.enable_alarms ? 1 : 0
  alarm_topic = [aws_sns_topic.alarms.arn]

  alb_dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  target_group_dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = var.target_group_arn_suffix
  }

  ecs_dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }
}

resource "aws_sns_topic" "alarms" {
  name              = "${var.name_prefix}-alarms"
  kms_master_key_id = var.sns_kms_master_key_id
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alarm_emails)

  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_cloudwatch_metric_alarm" "error_rate" {
  count = local.alarm_count

  alarm_name          = "${var.name_prefix}-slo-error-rate"
  alarm_description   = "Success SLO: (ELB 5xx + target 5xx) / requests is above ${var.error_rate_threshold_percent}% (only evaluated with >= ${var.error_rate_min_requests} requests per period)."
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.error_rate_threshold_percent
  evaluation_periods  = var.error_rate_evaluation_periods
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = local.alarm_topic
  ok_actions          = local.alarm_topic

  metric_query {
    id          = "error_rate"
    label       = "5xx error rate (%)"
    expression  = "IF(requests >= ${var.error_rate_min_requests}, 100 * (FILL(elb_5xx, 0) + FILL(target_5xx, 0)) / requests, 0)"
    return_data = true
  }

  metric_query {
    id = "requests"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "RequestCount"
      dimensions  = local.alb_dimensions
      period      = var.error_rate_period
      stat        = "Sum"
    }
  }

  metric_query {
    id = "elb_5xx"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_ELB_5XX_Count"
      dimensions  = local.alb_dimensions
      period      = var.error_rate_period
      stat        = "Sum"
    }
  }

  metric_query {
    id = "target_5xx"

    metric {
      namespace   = "AWS/ApplicationELB"
      metric_name = "HTTPCode_Target_5XX_Count"
      dimensions  = local.alb_dimensions
      period      = var.error_rate_period
      stat        = "Sum"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "latency" {
  count = local.alarm_count

  alarm_name          = "${var.name_prefix}-slo-latency"
  alarm_description   = "Latency SLO: ${var.latency_percentile} TargetResponseTime is above ${var.latency_threshold_seconds * 1000} ms."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = local.alb_dimensions
  extended_statistic  = var.latency_percentile
  period              = var.latency_period
  evaluation_periods  = var.latency_evaluation_periods
  datapoints_to_alarm = var.latency_datapoints_to_alarm
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.latency_threshold_seconds
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = local.alarm_topic
  ok_actions          = local.alarm_topic
}

resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  count = local.alarm_count

  alarm_name          = "${var.name_prefix}-unhealthy-targets"
  alarm_description   = "More than ${var.unhealthy_hosts_threshold} ALB targets are unhealthy."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = local.target_group_dimensions
  statistic           = "Maximum"
  period              = var.supporting_alarm_period
  evaluation_periods  = var.supporting_alarm_evaluation_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.unhealthy_hosts_threshold
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = local.alarm_topic
  ok_actions          = local.alarm_topic
}

resource "aws_cloudwatch_metric_alarm" "running_tasks" {
  count = local.alarm_count

  alarm_name          = "${var.name_prefix}-running-tasks-low"
  alarm_description   = "Fewer than ${var.min_running_tasks} ECS tasks are running (needs Container Insights)."
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  dimensions          = local.ecs_dimensions
  statistic           = "Minimum"
  period              = var.supporting_alarm_period
  evaluation_periods  = var.supporting_alarm_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = var.min_running_tasks
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = local.alarm_topic
  ok_actions          = local.alarm_topic
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count = local.alarm_count

  alarm_name          = "${var.name_prefix}-ecs-cpu-high"
  alarm_description   = "ECS service average CPU is above ${var.cpu_high_percent}%."
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = local.ecs_dimensions
  statistic           = "Average"
  period              = var.supporting_alarm_period
  evaluation_periods  = var.supporting_alarm_evaluation_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_high_percent
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = local.alarm_topic
  ok_actions          = local.alarm_topic
}

resource "aws_cloudwatch_metric_alarm" "memory_high" {
  count = local.alarm_count

  alarm_name          = "${var.name_prefix}-ecs-memory-high"
  alarm_description   = "ECS service average memory is above ${var.memory_high_percent}%."
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  dimensions          = local.ecs_dimensions
  statistic           = "Average"
  period              = var.supporting_alarm_period
  evaluation_periods  = var.supporting_alarm_evaluation_periods
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.memory_high_percent
  treat_missing_data  = var.treat_missing_data
  alarm_actions       = local.alarm_topic
  ok_actions          = local.alarm_topic
}
