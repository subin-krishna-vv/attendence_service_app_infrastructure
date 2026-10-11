# templates/iam-role

Creates one **IAM role that AWS services can assume**, and attaches managed policies to it. Per the repo rules, this is the only module allowed to declare `aws_iam_role`.

## Resources

- `aws_iam_role.this`: the trust policy allows `sts:AssumeRole` for the listed service principals only. By default it adds `aws:SourceAccount = <this account>` (confused-deputy protection).
- `aws_iam_role_policy_attachment.this`: one per entry in `policy_arns`.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | — | Full role name (≤ 64 chars) |
| `description` | string | — | What the role is for (non-empty) |
| `trusted_services` | list(string) | — | Service principals, e.g. `["ecs-tasks.amazonaws.com"]` |
| `policy_arns` | map(string) | `{}` | Policies to attach, keyed by a static name |
| `enable_source_account_condition` | bool | `true` | Add the `aws:SourceAccount` condition to the trust policy |

## Outputs

| Name | Description |
| --- | --- |
| `arn` | Role ARN |
| `name` | Role name |
| `unique_id` | Stable unique role ID |

## Toggles

| Toggle | Default | Effect |
| --- | --- | --- |
| `enable_source_account_condition` | `true` | Restricts the trust to requests made on behalf of this account. Turn it off only for a service that does not send `aws:SourceAccount`; AssumeRole fails if the service does not send it. |

## Example

```hcl
module "ecs_task_role" {
  source           = "../templates/iam-role"
  name             = "attendance-service-dev-use1-ecs-task"
  description      = "Role assumed by the attendance service containers"
  trusted_services = ["ecs-tasks.amazonaws.com"]
  policy_arns = {
    dynamodb = module.task_dynamodb_policy.arn
  }
}
```

## Design notes

- **Why a map for `policy_arns`:** `for_each` keys must be known at plan time. Policy ARNs created in the same apply are not known yet, but static keys like `dynamodb` are. Keys also stop attachments from being re-created when a policy is added or removed.
- **Only service principals are accepted.** They are validated to end in `.amazonaws.com`. Cross-account and user trust are out of scope.
- No permissions boundary and no inline policies (decided to keep this simple). The IAM path is the default `/`.
