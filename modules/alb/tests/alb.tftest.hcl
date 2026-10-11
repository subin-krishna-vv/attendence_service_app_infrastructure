mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
}

variables {
  name_prefix       = "attendance-service-dev-use1"
  company           = "abc"
  vpc_id            = "vpc-0123456789abcdef0"
  public_subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb", "subnet-0cccccccccccccccc"]
  certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
}

run "internet_facing_alb_in_three_public_subnets" {
  command = plan

  assert {
    condition     = aws_lb.this.name == "attendance-service-dev-use1-alb" && aws_lb.this.internal == false && aws_lb.this.load_balancer_type == "application"
    error_message = "ALB must be an internet-facing application load balancer named <name_prefix>-alb."
  }

  assert {
    condition     = length(aws_lb.this.subnets) == 3
    error_message = "ALB must span the 3 public subnets."
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == true
    error_message = "Deletion protection must be on by default."
  }
}

run "https_listener_with_tls13_res_pq_policy" {
  command = plan

  assert {
    condition     = length(aws_lb_listener.https) == 1 && aws_lb_listener.https[0].port == 443 && aws_lb_listener.https[0].protocol == "HTTPS"
    error_message = "Expected one HTTPS listener on 443."
  }

  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
    error_message = "HTTPS listener must use ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09."
  }

  assert {
    condition     = aws_lb_listener.https[0].certificate_arn == var.certificate_arn
    error_message = "HTTPS listener must use the given certificate."
  }
}

run "http_redirects_to_https" {
  command = plan

  assert {
    condition     = aws_lb_listener.http.port == 80 && aws_lb_listener.http.default_action[0].type == "redirect"
    error_message = "HTTP listener must redirect."
  }

  assert {
    condition = (
      aws_lb_listener.http.default_action[0].redirect[0].port == "443" &&
      aws_lb_listener.http.default_action[0].redirect[0].protocol == "HTTPS" &&
      aws_lb_listener.http.default_action[0].redirect[0].status_code == "HTTP_301"
    )
    error_message = "HTTP must 301-redirect to HTTPS on 443."
  }
}

run "target_group_ip_port_80_with_health_check" {
  command = plan

  assert {
    condition = (
      aws_lb_target_group.this.target_type == "ip" &&
      aws_lb_target_group.this.port == 80 &&
      aws_lb_target_group.this.protocol == "HTTP" &&
      aws_lb_target_group.this.deregistration_delay == "30"
    )
    error_message = "Target group must be ip/HTTP/80 with a 30 s deregistration delay."
  }

  assert {
    condition = (
      aws_lb_target_group.this.health_check[0].path == "/" &&
      aws_lb_target_group.this.health_check[0].matcher == "200" &&
      aws_lb_target_group.this.health_check[0].interval == 10 &&
      aws_lb_target_group.this.health_check[0].healthy_threshold == 2 &&
      aws_lb_target_group.this.health_check[0].unhealthy_threshold == 2
    )
    error_message = "Health check must be / expecting 200 every 10 s, healthy 2, unhealthy 2."
  }
}

run "access_logs_bucket_by_default" {
  command = plan

  assert {
    condition     = aws_s3_bucket.logs.bucket == "attendance-service-dev-use1-alb-logs-abc"
    error_message = "Log bucket must be named <name_prefix>-alb-logs-<company>."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.logs.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Log bucket must use SSE-S3 (the only encryption ALB access logs support)."
  }

  assert {
    condition     = aws_s3_bucket_versioning.logs.versioning_configuration[0].status == "Enabled"
    error_message = "Log bucket must have versioning enabled."
  }

  assert {
    condition     = one(aws_s3_bucket_lifecycle_configuration.logs.rule).expiration[0].days == 30
    error_message = "Access logs must expire after 30 days by default."
  }

  assert {
    condition = (
      aws_s3_bucket_public_access_block.logs.block_public_acls &&
      aws_s3_bucket_public_access_block.logs.block_public_policy &&
      aws_s3_bucket_public_access_block.logs.ignore_public_acls &&
      aws_s3_bucket_public_access_block.logs.restrict_public_buckets
    )
    error_message = "All public access blocks must be on."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.logs.policy).Statement[0].Principal.Service == "logdelivery.elasticloadbalancing.amazonaws.com"
    error_message = "Only the ELB log delivery service may write logs."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.logs.policy).Statement[0].Resource == "arn:aws:s3:::attendance-service-dev-use1-alb-logs-abc/AWSLogs/123456789012/*"
    error_message = "Log delivery must be limited to this account's AWSLogs prefix."
  }

  assert {
    condition     = jsondecode(aws_s3_bucket_policy.logs.policy).Statement[0].Condition.ArnLike["aws:SourceArn"] == "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/*"
    error_message = "Log delivery must be limited to this account's load balancers in this region."
  }

  assert {
    condition     = aws_lb.this.access_logs[0].enabled && aws_lb.this.access_logs[0].bucket == "attendance-service-dev-use1-alb-logs-abc"
    error_message = "ALB must send access logs to the log bucket."
  }
}

run "access_logs_off" {
  command = plan

  variables {
    enable_access_logs = false
  }

  assert {
    condition     = aws_s3_bucket.logs.bucket == "attendance-service-dev-use1-alb-logs-abc"
    error_message = "The log bucket must still exist when access logs are off."
  }

  assert {
    condition     = length(aws_lb.this.access_logs) == 0 || !aws_lb.this.access_logs[0].enabled
    error_message = "ALB access logs must be off."
  }
}

run "https_off_forwards_http" {
  command = plan

  variables {
    enable_https    = false
    certificate_arn = null
  }

  assert {
    condition     = length(aws_lb_listener.https) == 0 && output.https_listener_arn == null
    error_message = "No HTTPS listener when enable_https is false."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "forward"
    error_message = "HTTP must forward to the target group when HTTPS is off."
  }
}

run "deletion_protection_off" {
  command = plan

  variables {
    enable_deletion_protection = false
  }

  assert {
    condition     = aws_lb.this.enable_deletion_protection == false
    error_message = "Deletion protection must follow the toggle."
  }
}

run "https_requires_certificate" {
  command = plan

  variables {
    certificate_arn = null
  }

  expect_failures = [var.certificate_arn]
}

run "rejects_long_name_prefix" {
  command = plan

  variables {
    name_prefix = "attendance-service-staging-use1"
  }

  expect_failures = [var.name_prefix]
}

run "rejects_single_subnet" {
  command = plan

  variables {
    public_subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa"]
  }

  expect_failures = [var.public_subnet_ids]
}

run "alb_attribute_defaults_match_aws" {
  command = plan

  assert {
    condition = (
      aws_lb.this.drop_invalid_header_fields == false &&
      aws_lb.this.desync_mitigation_mode == "defensive" &&
      aws_lb.this.idle_timeout == 60 &&
      aws_lb.this.enable_http2 == true
    )
    error_message = "ALB attributes must default to the AWS defaults."
  }
}

run "overrides_listener_and_target_settings" {
  command = plan

  variables {
    ssl_policy                       = "ELBSecurityPolicy-TLS13-1-2-2021-06"
    deregistration_delay             = 60
    health_check_path                = "/health"
    health_check_matcher             = "200-299"
    health_check_interval            = 15
    health_check_healthy_threshold   = 3
    health_check_unhealthy_threshold = 4
    target_port                      = 8080
    drop_invalid_header_fields       = true
    desync_mitigation_mode           = "strictest"
    redirect_status_code             = "HTTP_302"
  }

  assert {
    condition     = aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "ssl_policy must follow the variable."
  }

  assert {
    condition = (
      aws_lb_target_group.this.deregistration_delay == "60" &&
      aws_lb_target_group.this.port == 8080 &&
      aws_lb_target_group.this.health_check[0].path == "/health" &&
      aws_lb_target_group.this.health_check[0].matcher == "200-299" &&
      aws_lb_target_group.this.health_check[0].interval == 15 &&
      aws_lb_target_group.this.health_check[0].healthy_threshold == 3 &&
      aws_lb_target_group.this.health_check[0].unhealthy_threshold == 4
    )
    error_message = "Target group settings must follow the variables."
  }

  assert {
    condition     = aws_lb.this.drop_invalid_header_fields == true && aws_lb.this.desync_mitigation_mode == "strictest"
    error_message = "ALB attributes must follow the variables."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].redirect[0].status_code == "HTTP_302"
    error_message = "Redirect status code must follow the variable."
  }
}

run "rejects_timeout_not_below_interval" {
  command = plan

  variables {
    health_check_interval = 10
    health_check_timeout  = 10
  }

  expect_failures = [var.health_check_timeout]
}

run "rejects_non_tls13_policy" {
  command = plan

  variables {
    ssl_policy = "ELBSecurityPolicy-2016-08"
  }

  expect_failures = [var.ssl_policy]
}
