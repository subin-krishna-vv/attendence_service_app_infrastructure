# waf

Creates a **regional AWS WAF web ACL** with AWS managed rule groups, associates it with a region's ALB, and sends its logs to CloudWatch Logs.

## Resources

Values shown are the variable defaults; each can be overridden (see Inputs).

| Resource | Purpose |
| --- | --- |
| `aws_wafv2_web_acl.this` | `<name_prefix>-waf`, `REGIONAL`, default action **allow**, 3 AWS managed rule groups in **count** mode |
| `aws_wafv2_web_acl_association.this` | Attaches the web ACL to the ALB |
| `aws_cloudwatch_log_group.this` | `aws-waf-logs-<name_prefix>` (WAF requires the `aws-waf-logs-` prefix), 30-day retention |
| `aws_wafv2_web_acl_logging_configuration.this` | Sends full request logs to the log group |

Managed rule groups, by priority:

| Priority | Rule group | What it catches |
| --- | --- | --- |
| 10 | `AWSManagedRulesCommonRuleSet` | OWASP-style attacks (XSS, path traversal, oversized bodies, bad user agents) |
| 20 | `AWSManagedRulesKnownBadInputsRuleSet` | Known exploit patterns (e.g. Log4j, Java deserialization) |
| 30 | `AWSManagedRulesAmazonIpReputationList` | IPs Amazon threat intelligence flags as malicious |

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name_prefix` | string | — (required) | Prefix for resource names: <project>-<env>-<region_short>, e.g. attendance-service-dev-use1. |
| `alb_arn` | string | — (required) | ARN of the Application Load Balancer the web ACL protects. |
| `default_action` | string | `"allow"` | Action for requests that match no rule. |
| `managed_rule_groups` | list(object) | see `variables.tf` | AWS managed rule groups to evaluate, in priority order (lower runs first). |
| `managed_rule_action` | string | `"count"` | count: rule groups only count matches (nothing is blocked). none: rule groups apply their own actions (block). |
| `cloudwatch_metrics_enabled` | bool | `true` | Publish CloudWatch metrics for the web ACL and each rule group. |
| `sampled_requests_enabled` | bool | `true` | Keep samples of requests matching each rule (viewable in the WAF console). |
| `enable_logging` | bool | `true` | Send full web ACL logs to a CloudWatch Logs log group. |
| `log_retention_days` | number | `30` | Days to keep WAF logs in CloudWatch Logs. |
| `log_group_kms_key_arn` | string | `null` | KMS key ARN to encrypt the WAF log group. null uses CloudWatch Logs default encryption. |

## Outputs

| Name | Description |
| --- | --- |
| `web_acl_arn` | Web ACL ARN |
| `web_acl_id` | Web ACL ID |
| `web_acl_name` | Web ACL name (`WebACL` dimension in CloudWatch metrics) |
| `log_group_name` | WAF log group, or `null` when logging is off |

## Toggles

| Toggle | Where | Default | Effect when `false` |
| --- | --- | --- | --- |
| `enable_waf` | **env stack**: `count` on the `module "waf"` block | `true` | No web ACL, association or logs. The ALB is unprotected. |
| `enable_logging` | module variable | `true` | No log group or logging configuration; CloudWatch metrics and sampled requests remain |

The whole-module toggle lives on the module block (the CLAUDE.md pattern for whole optional modules). With a `count` inside the module, Checkov couldn't link the logging configuration to the web ACL and falsely reported CKV2_AWS_31.

## Example

```hcl
module "waf" {
  source = "../../../modules/waf"
  count  = var.enable_waf ? 1 : 0

  name_prefix = "attendance-service-dev-use1"
  alb_arn     = module.alb.alb_arn
}
```

## Design notes

- **Count mode first.** `managed_rule_action = "count"` means rule groups only record matches in metrics, sampled requests and logs; nothing is blocked. Review the matches, then set `managed_rule_action = "none"` so the rule groups apply their own block actions.
- **No rate-based rule** for now (design decision).
- **Logs:** CloudWatch Logs, 30 days.
  - WAF creates the CloudWatch Logs resource policy for `delivery.logs.amazonaws.com` on its own. The identity running `terraform apply` needs `logs:CreateLogDelivery`, `logs:PutResourcePolicy`, `logs:DescribeResourcePolicies` and `logs:DescribeLogGroups`.
  - Retention under 1 year is a design decision (Checkov CKV_AWS_338 is skipped).
- **Default CloudWatch Logs encryption.** Set `log_group_kms_key_arn` to use your own KMS key.

## Cost

- **Web ACL:** $5/month.
- **Rule groups:** $1/month each, so $3.
- **Requests:** $0.60 per million.
- **Logs:** CloudWatch Logs ingestion (about $0.50/GB) plus storage.

That's roughly **$8/month per region before traffic**. Nothing is billed hourly.
