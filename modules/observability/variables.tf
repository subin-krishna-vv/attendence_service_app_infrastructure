variable "name_prefix" {
  description = "Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1."
  type        = string
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB (LoadBalancer metric dimension)."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group (TargetGroup metric dimension)."
  type        = string
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster (ClusterName metric dimension)."
  type        = string
}

variable "ecs_service_name" {
  description = "Name of the ECS service (ServiceName metric dimension)."
  type        = string
}

variable "alarm_emails" {
  description = "Email addresses subscribed to the alarm topic. Each address must confirm the subscription email from AWS."
  type        = list(string)
  default     = []
}

variable "enable_sns" {
  description = "Create the SNS alarm topic and its email subscriptions. When false, alarms still exist in CloudWatch but notify no one."
  type        = bool
  default     = true
}

variable "sns_kms_master_key_id" {
  description = "Customer-managed KMS key for the alarm topic. null leaves the topic unencrypted (CloudWatch cannot publish to a topic encrypted with the AWS-managed aws/sns key)."
  type        = string
  default     = null
}

variable "enable_alarms" {
  description = "Create the SLO and supporting CloudWatch alarms."
  type        = bool
  default     = true
}

variable "treat_missing_data" {
  description = "How alarms treat periods with no data."
  type        = string
  default     = "notBreaching"
}

variable "error_rate_threshold_percent" {
  description = "Error budget in percent: the error-rate alarm fires above this. 0.01 matches a 99.99% success SLO."
  type        = number
  default     = 0.01
}

variable "error_rate_period" {
  description = "Seconds per evaluation period of the error-rate alarm."
  type        = number
  default     = 300
}

variable "error_rate_evaluation_periods" {
  description = "Periods the error rate must breach before the alarm fires."
  type        = number
  default     = 1
}

variable "error_rate_min_requests" {
  description = "Minimum requests in a period before the error rate is evaluated (avoids 1-in-10 style alarms at low traffic)."
  type        = number
  default     = 1000
}

variable "latency_percentile" {
  description = "Percentile of TargetResponseTime the latency alarm watches."
  type        = string
  default     = "p99.99"
}

variable "latency_threshold_seconds" {
  description = "Latency SLO threshold in seconds."
  type        = number
  default     = 0.3
}

variable "latency_period" {
  description = "Seconds per evaluation period of the latency alarm."
  type        = number
  default     = 60
}

variable "latency_evaluation_periods" {
  description = "Periods evaluated by the latency alarm."
  type        = number
  default     = 3
}

variable "latency_datapoints_to_alarm" {
  description = "Breaching periods (out of latency_evaluation_periods) needed to fire the latency alarm."
  type        = number
  default     = 3
}

variable "unhealthy_hosts_threshold" {
  description = "The alarm fires when more unhealthy targets than this are seen."
  type        = number
  default     = 0
}

variable "min_running_tasks" {
  description = "The alarm fires when fewer ECS tasks than this are running (Container Insights metric)."
  type        = number
  default     = 3
}

variable "cpu_high_percent" {
  description = "Average ECS service CPU utilisation (%) above which the alarm fires."
  type        = number
  default     = 80
}

variable "memory_high_percent" {
  description = "Average ECS service memory utilisation (%) above which the alarm fires."
  type        = number
  default     = 80
}

variable "supporting_alarm_period" {
  description = "Seconds per evaluation period of the supporting (host, task, CPU, memory) alarms."
  type        = number
  default     = 60
}

variable "supporting_alarm_evaluation_periods" {
  description = "Periods the supporting alarms must breach before they fire."
  type        = number
  default     = 3
}
