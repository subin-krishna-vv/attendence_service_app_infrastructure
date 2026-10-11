output "alarm_topic_arn" {
  description = "ARN of the SNS topic alarms notify."
  value       = aws_sns_topic.alarms.arn
}

output "alarm_names" {
  description = "Names of the CloudWatch alarms, keyed by purpose (empty when alarms are disabled)."
  value = var.enable_alarms ? {
    error_rate      = aws_cloudwatch_metric_alarm.error_rate[0].alarm_name
    latency         = aws_cloudwatch_metric_alarm.latency[0].alarm_name
    unhealthy_hosts = aws_cloudwatch_metric_alarm.unhealthy_hosts[0].alarm_name
    running_tasks   = aws_cloudwatch_metric_alarm.running_tasks[0].alarm_name
    cpu_high        = aws_cloudwatch_metric_alarm.cpu_high[0].alarm_name
    memory_high     = aws_cloudwatch_metric_alarm.memory_high[0].alarm_name
  } : {}
}
