mock_provider "aws" {
  mock_data "aws_lb" {
    defaults = {
      arn_suffix = "app/attendance-service-dev-alb/0123456789abcdef"
    }
  }

  mock_data "aws_lb_target_group" {
    defaults = {
      arn_suffix = "targetgroup/attendance-service-dev-tg/0123456789abcdef"
    }
  }
}

variables {
  dashboard_name = "attendance-service-dev"
  regions = [
    { region = "us-east-1", name_prefix = "attendance-service-dev-use1" },
    { region = "us-east-2", name_prefix = "attendance-service-dev-use2" },
  ]
}

run "one_dashboard_with_a_column_per_region" {
  command = plan

  assert {
    condition     = aws_cloudwatch_dashboard.this.dashboard_name == "attendance-service-dev"
    error_message = "Dashboard must use dashboard_name."
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets) == 18
    error_message = "Expected 9 widgets (header + 8 metric widgets) per region."
  }

  assert {
    condition = toset([
      for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets : w.properties.region if w.type == "metric"
    ]) == toset(["us-east-1", "us-east-2"])
    error_message = "Metric widgets must cover both regions."
  }

  assert {
    condition = toset([
      for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets : w.x
    ]) == toset([0, 12])
    error_message = "Each region must get its own 12-wide column."
  }
}

run "looks_up_alb_and_target_group_by_name_in_each_region" {
  command = plan

  assert {
    condition     = data.aws_lb.this["us-east-2"].name == "attendance-service-dev-use2-alb" && data.aws_lb.this["us-east-2"].region == "us-east-2"
    error_message = "ALB must be looked up by <name_prefix>-alb in its own region."
  }

  assert {
    condition     = data.aws_lb_target_group.this["us-east-1"].name == "attendance-service-dev-use1-tg" && data.aws_lb_target_group.this["us-east-1"].region == "us-east-1"
    error_message = "Target group must be looked up by <name_prefix>-tg in its own region."
  }
}

run "slo_lines_on_success_and_latency_widgets" {
  command = plan

  assert {
    condition = contains([
      for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets :
      w.properties.annotations.horizontal[0].value if w.type == "metric" && startswith(w.properties.title, "Success rate")
    ], 99.99)
    error_message = "Success-rate widget must show the 99.99% SLO line."
  }

  assert {
    condition = contains([
      for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets :
      w.properties.annotations.horizontal[0].value if w.type == "metric" && startswith(w.properties.title, "Target response time")
    ], 0.3)
    error_message = "Latency widget must show the 300 ms SLO line."
  }
}

run "derived_ecs_and_waf_names" {
  command = plan

  assert {
    condition = anytrue([
      for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets :
      w.type == "metric" && startswith(w.properties.title, "Running tasks - us-east-1") &&
      w.properties.metrics[0][3] == "attendance-service-dev-use1-cluster" &&
      w.properties.metrics[0][5] == "attendance-service-dev-use1-nginx"
    ])
    error_message = "Running-tasks widget must use <name_prefix>-cluster and <name_prefix>-nginx."
  }

  assert {
    condition = anytrue([
      for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets :
      w.type == "metric" && startswith(w.properties.title, "WAF requests - us-east-2") &&
      w.properties.metrics[0][3] == "attendance-service-dev-use2-waf" &&
      length(w.properties.metrics) == 4
    ])
    error_message = "WAF widget must chart allowed requests plus each managed rule group for <name_prefix>-waf."
  }
}

run "waf_widget_off" {
  command = plan

  variables {
    include_waf_widget = false
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets) == 16
    error_message = "Expected 8 widgets per region without the WAF widget."
  }
}

run "single_region_uses_full_width" {
  command = plan

  variables {
    regions = [{ region = "us-east-1", name_prefix = "attendance-service-dev-use1" }]
  }

  assert {
    condition     = alltrue([for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets : w.width == 24])
    error_message = "A single region must use the full 24-unit width."
  }
}

run "rejects_duplicate_regions" {
  command = plan

  variables {
    regions = [
      { region = "us-east-1", name_prefix = "a" },
      { region = "us-east-1", name_prefix = "b" },
    ]
  }

  expect_failures = [var.regions]
}
