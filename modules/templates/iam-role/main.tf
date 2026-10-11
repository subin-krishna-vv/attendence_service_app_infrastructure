data "aws_caller_identity" "current" {}

locals {
  source_account_condition = {
    for k, v in {
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    } : k => v if var.enable_source_account_condition
  }

  trust_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [merge(
      {
        Sid       = "AllowServiceAssumeRole"
        Effect    = "Allow"
        Principal = { Service = var.trusted_services }
        Action    = "sts:AssumeRole"
      },
      local.source_account_condition,
    )]
  })
}

resource "aws_iam_role" "this" {
  name               = var.name
  description        = var.description
  assume_role_policy = local.trust_policy
}

resource "aws_iam_role_policy_attachment" "this" {
  for_each = var.policy_arns

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
