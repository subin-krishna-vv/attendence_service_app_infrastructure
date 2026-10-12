# templates/iam-policy

Creates one **customer-managed IAM policy** from a JSON document. Per the repo rules, this is the only module allowed to declare `aws_iam_policy`.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | — (required) | Full policy name, e.g. attendance-service-dev-use1-dax-dynamodb. |
| `description` | string | — (required) | What the policy grants and why. |
| `policy_json` | string | — (required) | IAM policy document as JSON (e.g. from data.aws_iam_policy_document.*.json or jsonencode). |
| `path` | string | `"/"` | IAM path for the policy. |

## Outputs

| Name | Description |
| --- | --- |
| `arn` | Policy ARN, passed to the `iam-role` template's `policy_arns` |
| `name` | Policy name |

## Toggles

None. Callers switch the whole module with `count` on the module block.

## Example

```hcl
data "aws_iam_policy_document" "dax_dynamodb" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query"]
    resources = [var.table_arn]
  }
}

module "dax_dynamodb_policy" {
  source      = "../templates/iam-policy"
  name        = "attendance-service-dev-use1-dax-dynamodb"
  description = "DynamoDB actions DAX needs on the regional table"
  policy_json = data.aws_iam_policy_document.dax_dynamodb.json
}
```

## Design notes

- Least privilege is the caller's job. Avoid `*` actions or resources unless the AWS service requires them, and add a comment explaining why when it does.
- Checkov cannot inspect the policy content here because it is a variable. Checkov scans the concrete documents in the calling modules.
- No inline policies. Attach policies through the `iam-role` template so every grant is a named, reusable policy.
- Tags come from the provider's `default_tags`.
