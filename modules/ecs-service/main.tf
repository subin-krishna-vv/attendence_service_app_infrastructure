data "aws_region" "current" {}

locals {
  service_name = "${var.name_prefix}-nginx"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? var.container_insights_mode : "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${local.service_name}"
  retention_in_days = var.log_retention_days
}

module "task_security_group" {
  source = "../templates/security-group"

  name        = "${var.name_prefix}-ecs-task"
  description = "ECS tasks: container port from the ALB only"
  vpc_id      = var.vpc_id
  ingress_rules = {
    container_from_alb = {
      description                  = "Container port from the ALB"
      from_port                    = var.container_port
      to_port                      = var.container_port
      referenced_security_group_id = var.alb_security_group_id
    }
  }
}

module "execution_logs_policy" {
  source = "../templates/iam-policy"

  name        = "${var.name_prefix}-ecs-execution-logs"
  description = "Lets the ECS agent write container logs to this service's log group only"
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "WriteServiceLogs"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.this.arn}:log-stream:*"
    }]
  })
}

module "execution_role" {
  source = "../templates/iam-role"

  name             = "${var.name_prefix}-ecs-execution"
  description      = "ECS task execution role: pulls the image and writes container logs"
  trusted_services = ["ecs-tasks.amazonaws.com"]
  policy_arns = {
    logs = module.execution_logs_policy.arn
  }
}

module "task_role" {
  source = "../templates/iam-role"

  name             = "${var.name_prefix}-ecs-task"
  description      = "ECS task role for the application containers (no permissions yet)"
  trusted_services = ["ecs-tasks.amazonaws.com"]
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.service_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = module.execution_role.arn
  task_role_arn            = module.task_role.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  container_definitions = jsonencode([{
    name      = var.container_name
    image     = var.container_image
    essential = true
    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.this.name
        awslogs-region        = data.aws_region.current.region
        awslogs-stream-prefix = var.container_name
      }
    }
  }])
}

resource "aws_ecs_service" "this" {
  name                               = local.service_name
  cluster                            = aws_ecs_cluster.this.arn
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = var.platform_version
  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent
  health_check_grace_period_seconds  = var.health_check_grace_period_seconds
  enable_execute_command             = var.enable_execute_command
  enable_ecs_managed_tags            = true
  propagate_tags                     = "SERVICE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [module.task_security_group.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container_name
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = var.enable_circuit_breaker
    rollback = var.enable_circuit_breaker
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_appautoscaling_target" "this" {
  count = var.enable_autoscaling ? 1 : 0

  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.min_capacity
  max_capacity       = var.max_capacity
}

resource "aws_appautoscaling_policy" "requests" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.service_name}-requests-per-target"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.requests_per_target
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${var.target_group_arn_suffix}"
    }
  }
}

resource "aws_appautoscaling_policy" "cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "${local.service_name}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[0].service_namespace
  resource_id        = aws_appautoscaling_target.this[0].resource_id
  scalable_dimension = aws_appautoscaling_target.this[0].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.cpu_target_percent
    scale_in_cooldown  = var.scale_in_cooldown
    scale_out_cooldown = var.scale_out_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
