# bootstrap/dev

Creates the **dev environment's Terraform state bucket**. Every dev stack (`envs/dev/global-data`, `envs/dev/us-east-1`, `envs/dev/us-east-2`, `envs/dev/global-dns`) stores its state here.

This stack uses **local state**, because the bucket it creates does not exist yet. Apply it once. Keep the local `terraform.tfstate` safe (it is gitignored); if it is lost, the bucket can be re-imported with `terraform import aws_s3_bucket.state <bucket-name>`.

## Resources

| Resource | Purpose |
| --- | --- |
| `aws_s3_bucket.state` | `<project>-<env>-tfstate-<company>` (e.g. `attendance-service-dev-tfstate-abc`); `force_destroy = false`, `prevent_destroy = true` |
| `aws_s3_bucket_versioning.state` | Versioning enabled, so every state write can be rolled back |
| `aws_s3_bucket_server_side_encryption_configuration.state` | SSE-S3: Amazon S3 managed keys (AES-256) |
| `aws_s3_bucket_public_access_block.state` | All four public-access blocks on |
| `aws_s3_bucket_ownership_controls.state` | `BucketOwnerEnforced` (ACLs disabled) |
| `aws_s3_bucket_lifecycle_configuration.state` | Expire noncurrent versions after N days; abort incomplete multipart uploads after 7 days |

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `project` | string | `"attendance-service"` | Project name, used as the naming prefix and the `project` tag. |
| `env` | string | `"dev"` | Environment name, used in the bucket name and the `env` tag. |
| `company` | string | `"abc"` | Company name, used as the state bucket name suffix to keep it globally unique. |
| `owner` | string | `"devops-team"` | Owning team, used for the `owner` tag. |
| `region` | string | `"us-east-1"` | AWS region for the state bucket. Holds state for every stack in the environment. |
| `noncurrent_version_expiration_days` | number | `90` | Days to keep noncurrent (previous) state file versions before they expire. |
| `force_destroy` | bool | `false` | Allow Terraform to delete the state bucket even when it holds objects. Keep false. |
| `enable_versioning` | bool | `true` | Keep previous versions of every state file (needed to roll back a bad apply). |
| `sse_algorithm` | string | `"AES256"` | Default server-side encryption: AES256 (SSE-S3) or aws:kms (SSE-KMS with the AWS-managed aws/s3 key). |
| `object_ownership` | string | `"BucketOwnerEnforced"` | S3 Object Ownership setting. BucketOwnerEnforced disables ACLs. |
| `abort_incomplete_multipart_upload_days` | number | `7` | Days after which incomplete multipart uploads are aborted. |
| `block_public_access` | bool | `true` | Turn on all four S3 Block Public Access settings for the bucket. |

## Outputs

| Name | Description |
| --- | --- |
| `state_bucket_name` | Bucket name for backend blocks |
| `state_bucket_arn` | Bucket ARN |
| `state_bucket_region` | Bucket region for backend blocks |

## Toggles

None. The state bucket is not optional.

## Usage

```sh
export AWS_PROFILE=<your-profile>   # or an SSO session
cd bootstrap/dev
terraform init
terraform plan
terraform apply
```

Backend block for later stacks (one key per stack):

```hcl
terraform {
  backend "s3" {
    bucket       = "attendance-service-dev-tfstate-abc"
    key          = "us-east-1/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking, no DynamoDB lock table
  }
}
```

## Design notes

- **No cross-region replication (CKV_AWS_144).** State for every dev stack, including us-east-2, lives in us-east-1. If S3 in us-east-1 is unavailable, Terraform cannot run for any dev stack until it recovers. Running services are not affected. Versioning gives point-in-time recovery of state.
- **No access logging (CKV_AWS_18).** It would need a second log bucket. CloudTrail management events still record bucket-level changes.
- **No event notifications (CKV2_AWS_62).** Nothing consumes them.
- **SSE-S3 instead of KMS (CKV_AWS_145).** S3-managed AES-256 encryption at rest, with no KMS key or KMS request costs. A deliberate choice for a state bucket.
- **No TLS-only bucket policy.** A deliberate choice: Terraform's S3 backend always uses HTTPS.
- Destroying this bucket requires removing `prevent_destroy` and emptying all object versions first.
