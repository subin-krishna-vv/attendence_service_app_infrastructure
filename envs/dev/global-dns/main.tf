module "route53_latency" {
  source = "../../../modules/route53-latency"

  zone_name                  = "${var.env}.${var.service_subdomain}.${var.base_domain}"
  record_name                = "${var.env}.${var.service_subdomain}.${var.base_domain}"
  regions                    = var.regions
  enable_health_checks       = var.enable_health_checks
  enable_health_check_alarms = var.enable_health_check_alarms
  alarm_topic_name           = var.enable_health_checks && var.enable_health_check_alarms ? var.alarm_topic_name : null
}

module "dashboard" {
  source = "../../../modules/dashboard"
  count  = var.enable_dashboard ? 1 : 0

  dashboard_name = var.dashboard_name
  regions        = var.regions
}
