# templates/iam-role

Creates one **IAM role that AWS services can assume**, and attaches managed policies to it. Per the repo rules, this is the only module allowed to declare `aws_iam_role`.

## Resources

- `aws_iam_role.this`: the trust policy allows `sts:AssumeRole` for the listed service principals only. By default it adds `aws:SourceAccount = <this account>` (confused-deputy protection).
- `aws_iam_role_policy_attachment.this`: one per entry in `policy_arns`.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | string | — (required) | Full role name, e.g. attendance-service-dev-use1-ecs-task. |
| `description` | string | — (required) | What the role is for. |
| `trusted_services` | list(string) | — (required) | AWS service principals allowed to assume the role, e.g. ["ecs-tasks.amazonaws.com"]. |
| `policy_arns` | map(string) | `{}` | Managed policies to attach, keyed by a static name (keys must be known at plan time), e.g. { dynamodb = module.dax_policy.arn }. |
| `enable_source_account_condition` | bool | `true` | Add an aws:SourceAccount condition to the trust policy (confused-deputy protection). Turn off only for services that do not send aws:SourceAccount. |
| `path` | string | `"/"` | IAM path for the role. |
| `max_session_duration` | number | `3600` | Maximum session duration in seconds for credentials issued for this role. |

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
