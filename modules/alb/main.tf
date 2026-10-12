data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_partition" "current" {}

locals {
  account_id      = data.aws_caller_identity.current.account_id
  log_bucket_name = "${var.name_prefix}-alb-logs-${var.company}"

  ingress_rules = merge(
    {
      http_from_internet = {
        description = "HTTP from the internet"
        from_port   = var.http_port
        to_port     = var.http_port
        cidr_ipv4   = var.ingress_cidr_ipv4
      }
    },
    var.enable_https ? {
      https_from_internet = {
        description = "HTTPS from the internet"
        from_port   = var.https_port
        to_port     = var.https_port
        cidr_ipv4   = var.ingress_cidr_ipv4
      }
    } : {},
  )
}

module "security_group" {
  source = "../templates/security-group"

  name          = "${var.name_prefix}-alb"
  description   = "ALB: HTTP and HTTPS from the internet"
  vpc_id        = var.vpc_id
  ingress_rules = local.ingress_rules
}

resource "aws_s3_bucket" "logs" {
  bucket        = local.log_bucket_name
  force_destroy = var.log_bucket_force_destroy
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.access_log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.log_noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.log_abort_incomplete_multipart_upload_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.logs]
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowAlbLogDelivery"
      Effect    = "Allow"
      Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "arn:${data.aws_partition.current.partition}:s3:::${local.log_bucket_name}/AWSLogs/${local.account_id}/*"
      Condition = {
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:elasticloadbalancing:${data.aws_region.current.region}:${local.account_id}:loadbalancer/*"
        }
      }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.logs]
}

resource "aws_lb" "this" {
  name                       = "${var.name_prefix}-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [module.security_group.id]
  subnets                    = var.public_subnet_ids
  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.idle_timeout
  enable_http2               = var.enable_http2
  drop_invalid_header_fields = var.drop_invalid_header_fields
  desync_mitigation_mode     = var.desync_mitigation_mode

  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [local.log_bucket_name] : []

    content {
      bucket  = access_logs.value
      enabled = true
    }
  }

  depends_on = [aws_s3_bucket_policy.logs]
}

resource "aws_lb_target_group" "this" {
  name                 = "${var.name_prefix}-tg"
  port                 = var.target_port
  protocol             = var.target_protocol
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = var.deregistration_delay

  health_check {
    enabled             = true
    protocol            = var.target_protocol
    path                = var.health_check_path
    matcher             = var.health_check_matcher
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
  }
}

resource "aws_lb_listener" "https" {
  count = var.enable_https ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = var.https_port
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.http_port
  protocol          = "HTTP"

  default_action {
    type             = var.enable_https ? "redirect" : "forward"
    target_group_arn = var.enable_https ? null : aws_lb_target_group.this.arn

    dynamic "redirect" {
      for_each = var.enable_https ? [1] : []

      content {
        port        = tostring(var.https_port)
        protocol    = "HTTPS"
        status_code = var.redirect_status_code
      }
    }
  }
}
