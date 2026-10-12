resource "aws_wafv2_web_acl" "this" {
  name  = "${var.name_prefix}-waf"
  scope = "REGIONAL"

  default_action {
    dynamic "allow" {
      for_each = var.default_action == "allow" ? [1] : []
      content {}
    }

    dynamic "block" {
      for_each = var.default_action == "block" ? [1] : []
      content {}
    }
  }

  dynamic "rule" {
    for_each = var.managed_rule_groups

    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "count" {
          for_each = var.managed_rule_action == "count" ? [1] : []
          content {}
        }

        dynamic "none" {
          for_each = var.managed_rule_action == "none" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
        metric_name                = rule.value.name
        sampled_requests_enabled   = var.sampled_requests_enabled
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.cloudwatch_metrics_enabled
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = var.sampled_requests_enabled
  }
}

resource "aws_wafv2_web_acl_association" "this" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}

resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_logging ? 1 : 0

  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.log_group_kms_key_arn
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.this[0].arn]
}
