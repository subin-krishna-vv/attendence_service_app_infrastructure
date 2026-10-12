locals {
  domain_name = var.base_domain == null ? null : "${var.env}.${var.service_subdomain}.${var.base_domain}"
}

module "route53_latency" {
  source = "../../../modules/route53-latency"
  count  = var.enable_dns_records ? 1 : 0

  zone_name                  = local.domain_name
  record_name                = local.domain_name
  regions                    = var.regions
  enable_health_checks       = var.enable_health_checks
  enable_health_check_alarms = var.enable_health_check_alarms
  alarm_topic_name           = var.enable_health_checks && var.enable_health_check_alarms && var.enable_sns ? var.alarm_topic_name : null
}

module "dashboard" {
  source = "../../../modules/dashboard"
  count  = var.enable_dashboard ? 1 : 0

  dashboard_name = var.dashboard_name
  regions        = var.regions
}
