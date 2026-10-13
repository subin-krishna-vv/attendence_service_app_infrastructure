data "aws_route53_zone" "this" {
  name         = var.zone_name
  private_zone = false
}

data "aws_lb" "this" {
  for_each = local.regions

  region = each.key
  name   = "${each.value.name_prefix}${var.alb_name_suffix}"
}

data "aws_sns_topic" "alarms" {
  count = local.create_alarms && var.alarm_topic_name != null ? 1 : 0

  name = var.alarm_topic_name
}

locals {
  regions       = { for r in var.regions : r.region => r }
  create_alarms = var.enable_health_checks && var.enable_health_check_alarms
  alarm_actions = [for t in data.aws_sns_topic.alarms : t.arn]
}

resource "aws_route53_health_check" "this" {
  for_each = var.enable_health_checks ? local.regions : {}

  fqdn              = data.aws_lb.this[each.key].dns_name
  type              = var.health_check_type
  port              = var.health_check_port
  resource_path     = var.health_check_path
  request_interval  = var.health_check_request_interval
  failure_threshold = var.health_check_failure_threshold
  measure_latency   = var.health_check_measure_latency
  regions           = var.health_check_regions
  enable_sni        = var.health_check_type == "HTTPS"

  tags = {
    Name = "${each.value.name_prefix}-health"
  }
}

resource "aws_route53_record" "this" {
  for_each = local.regions

  zone_id         = data.aws_route53_zone.this.zone_id
  name            = var.record_name
  type            = "A"
  set_identifier  = each.key
  health_check_id = var.enable_health_checks ? aws_route53_health_check.this[each.key].id : null

  latency_routing_policy {
    region = each.key
  }

  alias {
    name                   = data.aws_lb.this[each.key].dns_name
    zone_id                = data.aws_lb.this[each.key].zone_id
    evaluate_target_health = var.evaluate_target_health
  }
}

resource "aws_cloudwatch_metric_alarm" "health" {
  for_each = local.create_alarms ? local.regions : {}

  alarm_name          = "${each.value.name_prefix}-route53-health"
  alarm_description   = "Route 53 health check for the ${each.key} ALB is failing; traffic is being routed away from ${each.key}."
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  dimensions          = { HealthCheckId = aws_route53_health_check.this[each.key].id }
  statistic           = "Minimum"
  period              = var.alarm_period
  evaluation_periods  = var.alarm_evaluation_periods
  comparison_operator = "LessThanThreshold"
  threshold           = 1
  treat_missing_data  = "breaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}
