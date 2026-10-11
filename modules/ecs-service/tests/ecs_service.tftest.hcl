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
}

variables {
  name_prefix             = "attendance-service-dev-use1"
  vpc_id                  = "vpc-0123456789abcdef0"
  private_subnet_ids      = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb", "subnet-0cccccccccccccccc"]
  alb_security_group_id   = "sg-0a1b2c3d4e5f60718"
  target_group_arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/attendance-service-dev-use1-tg/0123456789abcdef"
  alb_arn_suffix          = "app/attendance-service-dev-use1-alb/0123456789abcdef"
  target_group_arn_suffix = "targetgroup/attendance-service-dev-use1-tg/0123456789abcdef"
}

run "cluster_with_container_insights" {
  command = plan

  assert {
    condition     = aws_ecs_cluster.this.name == "attendance-service-dev-use1-cluster"
    error_message = "Cluster must be named <name_prefix>-cluster."
  }

  assert {
    condition     = one([for s in aws_ecs_cluster.this.setting : s.value if s.name == "containerInsights"]) == "enabled"
    error_message = "Standard Container Insights must be on by default."
  }

  assert {
    condition     = aws_ecs_cluster_capacity_providers.this.capacity_providers == toset(["FARGATE"])
    error_message = "Only on-demand Fargate may be used (no Fargate Spot)."
  }
}

run "task_definition_pinned_nginx_on_fargate" {
  command = plan

  assert {
    condition = (
      aws_ecs_task_definition.this.requires_compatibilities == toset(["FARGATE"]) &&
      aws_ecs_task_definition.this.network_mode == "awsvpc" &&
      aws_ecs_task_definition.this.cpu == "256" &&
      aws_ecs_task_definition.this.memory == "512"
    )
    error_message = "Task must be Fargate/awsvpc with 0.25 vCPU and 512 MiB."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].image == "nginx:1.30.5@sha256:9bf97bd7714f5e24c1ccd545ecb9eb5435cb6d109c97cebb15e7e455e0239edb"
    error_message = "Container must run nginx pinned by tag and digest."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings[0].containerPort == 80
    error_message = "Container must listen on port 80."
  }

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.logDriver == "awslogs" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-group"] == "/ecs/attendance-service-dev-use1-nginx"
    )
    error_message = "Container must log to its CloudWatch log group via awslogs."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this.retention_in_days == 30
    error_message = "Container logs must be kept 30 days by default."
  }
}

run "service_rolling_deploy_without_public_ip" {
  command = plan

  assert {
    condition     = aws_ecs_service.this.launch_type == "FARGATE" && aws_ecs_service.this.desired_count == 3
    error_message = "Service must run 3 Fargate tasks initially."
  }

  assert {
    condition     = aws_ecs_service.this.network_configuration[0].assign_public_ip == false
    error_message = "Tasks must not get a public IP."
  }

  assert {
    condition     = aws_ecs_service.this.deployment_minimum_healthy_percent == 100 && aws_ecs_service.this.deployment_maximum_percent == 200
    error_message = "Rolling deployments must keep 100% healthy and allow 200%."
  }

  assert {
    condition     = aws_ecs_service.this.deployment_circuit_breaker[0].enable && aws_ecs_service.this.deployment_circuit_breaker[0].rollback
    error_message = "Circuit breaker with rollback must be on by default."
  }

  assert {
    condition = (
      one(aws_ecs_service.this.load_balancer).target_group_arn == var.target_group_arn &&
      one(aws_ecs_service.this.load_balancer).container_name == "nginx" &&
      one(aws_ecs_service.this.load_balancer).container_port == 80
    )
    error_message = "Service must register the nginx container port 80 in the target group."
  }

  assert {
    condition     = aws_ecs_service.this.enable_execute_command == false
    error_message = "ECS Exec must be off by default."
  }
}

run "task_security_group_only_admits_alb" {
  command = plan

  assert {
    condition     = length(module.task_security_group.ingress_rules) == 1
    error_message = "Task security group must have exactly one ingress rule."
  }

  assert {
    condition = (
      module.task_security_group.ingress_rules["container_from_alb"].referenced_security_group_id == var.alb_security_group_id &&
      module.task_security_group.ingress_rules["container_from_alb"].cidr_ipv4 == null &&
      module.task_security_group.ingress_rules["container_from_alb"].from_port == 80
    )
    error_message = "Task security group must only admit the ALB security group on port 80."
  }
}

run "autoscaling_on_requests_and_cpu" {
  command = plan

  assert {
    condition     = aws_appautoscaling_target.this[0].min_capacity == 3 && aws_appautoscaling_target.this[0].max_capacity == 6
    error_message = "Autoscaling must keep between 3 and 6 tasks."
  }

  assert {
    condition = (
      aws_appautoscaling_policy.requests[0].target_tracking_scaling_policy_configuration[0].target_value == 1000 &&
      aws_appautoscaling_policy.requests[0].target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ALBRequestCountPerTarget" &&
      aws_appautoscaling_policy.requests[0].target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].resource_label == "app/attendance-service-dev-use1-alb/0123456789abcdef/targetgroup/attendance-service-dev-use1-tg/0123456789abcdef"
    )
    error_message = "Request policy must target 1000 ALB requests per task on this ALB/target group."
  }

  assert {
    condition     = aws_appautoscaling_policy.cpu[0].target_tracking_scaling_policy_configuration[0].target_value == 60
    error_message = "CPU policy must target 60%."
  }
}

run "toggles_off" {
  command = plan

  variables {
    enable_autoscaling        = false
    enable_circuit_breaker    = false
    enable_container_insights = false
  }

  assert {
    condition     = length(aws_appautoscaling_target.this) == 0 && length(aws_appautoscaling_policy.requests) == 0 && length(aws_appautoscaling_policy.cpu) == 0
    error_message = "No autoscaling resources when enable_autoscaling is false."
  }

  assert {
    condition     = aws_ecs_service.this.deployment_circuit_breaker[0].enable == false
    error_message = "Circuit breaker must be off when enable_circuit_breaker is false."
  }

  assert {
    condition     = one([for s in aws_ecs_cluster.this.setting : s.value if s.name == "containerInsights"]) == "disabled"
    error_message = "Container Insights must be disabled when enable_container_insights is false."
  }
}

run "rejects_unpinned_image" {
  command = plan

  variables {
    container_image = "nginx:1.30.5"
  }

  expect_failures = [var.container_image]
}

run "rejects_latest_tag" {
  command = plan

  variables {
    container_image = "nginx:latest@sha256:9bf97bd7714f5e24c1ccd545ecb9eb5435cb6d109c97cebb15e7e455e0239edb"
  }

  expect_failures = [var.container_image]
}

run "rejects_max_below_min" {
  command = plan

  variables {
    min_capacity = 6
    max_capacity = 3
  }

  expect_failures = [var.max_capacity]
}

run "separate_execution_and_task_roles" {
  command = plan

  assert {
    condition     = module.execution_role.name == "attendance-service-dev-use1-ecs-execution" && module.task_role.name == "attendance-service-dev-use1-ecs-task"
    error_message = "Execution role and task role must be two separate roles."
  }
}
