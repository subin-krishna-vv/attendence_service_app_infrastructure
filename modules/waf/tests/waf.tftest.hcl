mock_provider "aws" {}

variables {
  name_prefix = "attendance-service-dev-use1"
  alb_arn     = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/attendance-service-dev-use1-alb/0123456789abcdef"
}

run "regional_web_acl_allows_by_default" {
  command = plan

  assert {
    condition     = aws_wafv2_web_acl.this.name == "attendance-service-dev-use1-waf" && aws_wafv2_web_acl.this.scope == "REGIONAL"
    error_message = "Web ACL must be a REGIONAL web ACL named <name_prefix>-waf."
  }

  assert {
    condition     = length(aws_wafv2_web_acl.this.default_action[0].allow) == 1 && length(aws_wafv2_web_acl.this.default_action[0].block) == 0
    error_message = "Default action must be allow."
  }
}

run "three_aws_managed_rule_groups_in_count_mode" {
  command = plan

  assert {
    condition = toset([for r in aws_wafv2_web_acl.this.rule : r.name]) == toset([
      "AWSManagedRulesCommonRuleSet",
      "AWSManagedRulesKnownBadInputsRuleSet",
      "AWSManagedRulesAmazonIpReputationList",
    ])
    error_message = "Expected exactly the Core, Known bad inputs and Amazon IP reputation rule groups."
  }

  assert {
    condition     = alltrue([for r in aws_wafv2_web_acl.this.rule : r.statement[0].managed_rule_group_statement[0].vendor_name == "AWS"])
    error_message = "All rule groups must be AWS managed."
  }

  assert {
    condition     = alltrue([for r in aws_wafv2_web_acl.this.rule : length(r.override_action[0].count) == 1 && length(r.override_action[0].none) == 0])
    error_message = "All rule groups must only count by default."
  }

  assert {
    condition     = alltrue([for r in aws_wafv2_web_acl.this.rule : length(r.statement[0].rate_based_statement) == 0])
    error_message = "There must be no rate-based rule."
  }
}

run "associated_with_alb" {
  command = plan

  assert {
    condition     = aws_wafv2_web_acl_association.this.resource_arn == var.alb_arn
    error_message = "Web ACL must be associated with the given ALB."
  }
}

run "logs_to_cloudwatch_for_30_days" {
  command = plan

  assert {
    condition     = aws_cloudwatch_log_group.this[0].name == "aws-waf-logs-attendance-service-dev-use1"
    error_message = "Log group name must start with aws-waf-logs- (WAF requirement)."
  }

  assert {
    condition     = aws_cloudwatch_log_group.this[0].retention_in_days == 30
    error_message = "WAF logs must be kept for 30 days by default."
  }

  assert {
    condition     = length(aws_wafv2_web_acl_logging_configuration.this) == 1
    error_message = "Web ACL logging must be configured."
  }
}

run "block_mode" {
  command = plan

  variables {
    managed_rule_action = "none"
  }

  assert {
    condition     = alltrue([for r in aws_wafv2_web_acl.this.rule : length(r.override_action[0].none) == 1 && length(r.override_action[0].count) == 0])
    error_message = "With managed_rule_action = none, rule groups must apply their own actions."
  }
}

run "logging_off" {
  command = plan

  variables {
    enable_logging = false
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 0 && length(aws_wafv2_web_acl_logging_configuration.this) == 0 && output.log_group_name == null
    error_message = "No log group or logging configuration when enable_logging is false."
  }

  assert {
    condition     = aws_wafv2_web_acl.this.name == "attendance-service-dev-use1-waf"
    error_message = "Disabling logging must not remove the web ACL."
  }
}


run "rejects_invalid_retention" {
  command = plan

  variables {
    log_retention_days = 31
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_duplicate_priorities" {
  command = plan

  variables {
    managed_rule_groups = [
      { name = "AWSManagedRulesCommonRuleSet", priority = 10 },
      { name = "AWSManagedRulesKnownBadInputsRuleSet", priority = 10 },
    ]
  }

  expect_failures = [var.managed_rule_groups]
}
