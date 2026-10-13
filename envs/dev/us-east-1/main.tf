locals {
  name_prefix   = "${var.project}-${var.env}-${var.region_short}"
  domain_name   = var.base_domain == null ? null : "${var.env}.${var.service_subdomain}.${var.base_domain}"
  https_enabled = var.enable_https && var.enable_certificate
}

module "vpc" {
  source = "../../../modules/vpc"

  name_prefix              = local.name_prefix
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_subnet_cidrs     = var.private_subnet_cidrs
  enable_nat_gateway       = var.enable_nat_gateway
  enable_s3_endpoint       = var.enable_s3_endpoint
  enable_dynamodb_endpoint = var.enable_dynamodb_endpoint
}

module "certificate" {
  source = "../../../modules/acm-certificate"
  count  = var.enable_certificate ? 1 : 0

  domain_name     = local.domain_name
  zone_name       = local.domain_name
  enable_wildcard = var.enable_wildcard_certificate
}

module "alb" {
  source = "../../../modules/alb"

  name_prefix                = local.name_prefix
  company                    = var.company
  vpc_id                     = module.vpc.vpc_id
  public_subnet_ids          = module.vpc.public_subnet_ids
  certificate_arn            = local.https_enabled ? module.certificate[0].certificate_arn : null
  enable_https               = local.https_enabled
  enable_access_logs         = var.enable_alb_access_logs
  access_log_retention_days  = var.alb_access_log_retention_days
  enable_deletion_protection = var.enable_alb_deletion_protection
}

module "waf" {
  source = "../../../modules/waf"
  count  = var.enable_waf ? 1 : 0

  name_prefix         = local.name_prefix
  alb_arn             = module.alb.alb_arn
  managed_rule_action = var.waf_managed_rule_action
  log_retention_days  = var.waf_log_retention_days
}

module "ecs_service" {
  source = "../../../modules/ecs-service"

  name_prefix               = local.name_prefix
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  alb_security_group_id     = module.alb.security_group_id
  target_group_arn          = module.alb.target_group_arn
  alb_arn_suffix            = module.alb.alb_arn_suffix
  target_group_arn_suffix   = module.alb.target_group_arn_suffix
  container_image           = var.container_image
  task_cpu                  = var.task_cpu
  task_memory               = var.task_memory
  desired_count             = var.desired_count
  enable_autoscaling        = var.enable_autoscaling
  min_capacity              = var.min_capacity
  max_capacity              = var.max_capacity
  requests_per_target       = var.requests_per_target
  cpu_target_percent        = var.cpu_target_percent
  enable_circuit_breaker    = var.enable_circuit_breaker
  enable_container_insights = var.enable_container_insights
  log_retention_days        = var.container_log_retention_days

  depends_on = [module.alb]
}

module "observability" {
  source = "../../../modules/observability"

  name_prefix             = local.name_prefix
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix
  ecs_cluster_name        = module.ecs_service.cluster_name
  ecs_service_name        = module.ecs_service.service_name
  enable_alarms           = var.enable_alarms
  enable_sns              = var.enable_sns
  alarm_emails            = var.alarm_emails
  min_running_tasks       = var.min_capacity
}
