variable "name_prefix" {
  description = "Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name_prefix)) && length(var.name_prefix) <= 40
    error_message = "name_prefix must be lowercase alphanumeric with hyphens and at most 40 characters (IAM role names are limited to 64)."
  }
}

variable "vpc_id" {
  description = "ID of the VPC for the task security group."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (one per AZ) the tasks run in."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "private_subnet_ids must contain at least 2 subnets in different AZs."
  }
}

variable "alb_security_group_id" {
  description = "ID of the ALB security group, the only source allowed to reach the tasks."
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group the service registers its tasks in."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB, used by the ALBRequestCountPerTarget scaling policy."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group, used by the ALBRequestCountPerTarget scaling policy."
  type        = string
}

variable "container_image" {
  description = "Container image, pinned by tag and digest (no latest)."
  type        = string
  default     = "nginx:1.30.5@sha256:9bf97bd7714f5e24c1ccd545ecb9eb5435cb6d109c97cebb15e7e455e0239edb"

  validation {
    condition     = can(regex("@sha256:[a-f0-9]{64}$", var.container_image)) && !can(regex(":latest@", var.container_image))
    error_message = "container_image must be pinned by digest (…@sha256:<64 hex>) and must not use the latest tag."
  }
}

variable "container_name" {
  description = "Name of the container in the task definition (used by the ALB registration)."
  type        = string
  default     = "nginx"
}

variable "container_port" {
  description = "Port the container listens on."
  type        = number
  default     = 80

  validation {
    condition     = var.container_port >= 1 && var.container_port <= 65535
    error_message = "container_port must be between 1 and 65535."
  }
}

variable "task_cpu" {
  description = "Task CPU units (256 = 0.25 vCPU)."
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096, 8192, 16384], var.task_cpu)
    error_message = "task_cpu must be a Fargate CPU value: 256, 512, 1024, 2048, 4096, 8192 or 16384."
  }
}

variable "task_memory" {
  description = "Task memory in MiB. Must be a valid Fargate combination with task_cpu."
  type        = number
  default     = 512

  validation {
    condition     = var.task_memory >= 512 && var.task_memory <= 122880
    error_message = "task_memory must be between 512 and 122880 MiB."
  }
}

variable "cpu_architecture" {
  description = "CPU architecture of the tasks."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "platform_version" {
  description = "Fargate platform version."
  type        = string
  default     = "LATEST"
}

variable "desired_count" {
  description = "Initial number of tasks. After creation, autoscaling owns the count (changes here are ignored)."
  type        = number
  default     = 3

  validation {
    condition     = var.desired_count >= 0 && floor(var.desired_count) == var.desired_count
    error_message = "desired_count must be a non-negative whole number."
  }
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum share of desired tasks that must stay healthy during a deployment."
  type        = number
  default     = 100

  validation {
    condition     = var.deployment_minimum_healthy_percent >= 0 && var.deployment_minimum_healthy_percent <= 100
    error_message = "deployment_minimum_healthy_percent must be between 0 and 100."
  }
}

variable "deployment_maximum_percent" {
  description = "Maximum share of desired tasks that may run during a deployment."
  type        = number
  default     = 200

  validation {
    condition     = var.deployment_maximum_percent >= 100 && var.deployment_maximum_percent <= 200
    error_message = "deployment_maximum_percent must be between 100 and 200."
  }
}

variable "enable_circuit_breaker" {
  description = "Stop a failing deployment and roll back to the last working task definition."
  type        = bool
  default     = true
}

variable "health_check_grace_period_seconds" {
  description = "Seconds after a task starts during which failed ALB health checks are ignored."
  type        = number
  default     = 30

  validation {
    condition     = var.health_check_grace_period_seconds >= 0 && var.health_check_grace_period_seconds <= 2147483647
    error_message = "health_check_grace_period_seconds must be non-negative."
  }
}

variable "enable_autoscaling" {
  description = "Scale the service with target tracking on ALB requests per task and CPU."
  type        = bool
  default     = true
}

variable "min_capacity" {
  description = "Minimum number of tasks when autoscaling is enabled."
  type        = number
  default     = 3

  validation {
    condition     = var.min_capacity >= 1 && floor(var.min_capacity) == var.min_capacity
    error_message = "min_capacity must be a positive whole number."
  }
}

variable "max_capacity" {
  description = "Maximum number of tasks when autoscaling is enabled."
  type        = number
  default     = 6

  validation {
    condition     = var.max_capacity >= var.min_capacity && floor(var.max_capacity) == var.max_capacity
    error_message = "max_capacity must be a whole number >= min_capacity."
  }
}

variable "requests_per_target" {
  description = "Target ALB requests per task per minute for the ALBRequestCountPerTarget policy."
  type        = number
  default     = 1000

  validation {
    condition     = var.requests_per_target > 0
    error_message = "requests_per_target must be positive."
  }
}

variable "cpu_target_percent" {
  description = "Target average CPU utilisation (%) for the CPU policy."
  type        = number
  default     = 60

  validation {
    condition     = var.cpu_target_percent > 0 && var.cpu_target_percent <= 100
    error_message = "cpu_target_percent must be between 1 and 100."
  }
}

variable "scale_in_cooldown" {
  description = "Seconds to wait after a scale-in before another scale-in."
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Seconds to wait after a scale-out before another scale-out."
  type        = number
  default     = 60
}

variable "enable_container_insights" {
  description = "Turn on CloudWatch Container Insights for the cluster."
  type        = bool
  default     = true
}

variable "container_insights_mode" {
  description = "Container Insights level when enabled: enabled (standard) or enhanced (more metrics, extra cost)."
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "enhanced"], var.container_insights_mode)
    error_message = "container_insights_mode must be enabled or enhanced."
  }
}

variable "log_retention_days" {
  description = "Days to keep container logs in CloudWatch Logs."
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_days)
    error_message = "log_retention_days must be a CloudWatch Logs retention value."
  }
}

variable "enable_execute_command" {
  description = "Allow ECS Exec (interactive shell into running tasks). Keep false unless debugging."
  type        = bool
  default     = false
}
