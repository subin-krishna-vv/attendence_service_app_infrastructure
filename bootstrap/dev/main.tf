data "aws_caller_identity" "current" {}

locals {
  # Account ID suffix keeps the globally unique bucket name predictable without hard-coding it.
  state_bucket_name = "${var.project}-${var.env}-tfstate-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket" "state" {
  #checkov:skip=CKV_AWS_18:Access logging needs a separate log bucket; not justified for a low-traffic state bucket. Accepted deviation, see README.
  #checkov:skip=CKV_AWS_144:Cross-region replication deliberately not used for state; versioning covers recovery. Accepted deviation, see README.
  #checkov:skip=CKV2_AWS_62:Event notifications have no consumer for a state bucket. Accepted deviation, see README.
  #checkov:skip=CKV_AWS_145:SSE-S3 (S3-managed AES-256) chosen deliberately for state; no KMS key to manage. Accepted deviation, see README.
  bucket        = local.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# SSE-S3: Amazon S3 managed keys (AES-256).
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Lifecycle rules on a versioned bucket must be applied after versioning is enabled.
  depends_on = [aws_s3_bucket_versioning.state]
}
