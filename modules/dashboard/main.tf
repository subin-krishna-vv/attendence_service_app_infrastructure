data "aws_lb" "this" {
  for_each = { for r in var.regions : r.region => r }

  region = each.key
  name   = "${each.value.name_prefix}${var.alb_name_suffix}"
}

data "aws_lb_target_group" "this" {
  for_each = { for r in var.regions : r.region => r }

  region = each.key
  name   = "${each.value.name_prefix}${var.target_group_name_suffix}"
}

locals {
  column_width = floor(24 / length(var.regions))

  columns = [
    for i, r in var.regions : {
      region       = r.region
      x            = i * local.column_width
      alb          = data.aws_lb.this[r.region].arn_suffix
      target_group = data.aws_lb_target_group.this[r.region].arn_suffix
      cluster      = "${r.name_prefix}${var.ecs_cluster_name_suffix}"
      service      = "${r.name_prefix}${var.ecs_service_name_suffix}"
      web_acl      = "${r.name_prefix}${var.web_acl_name_suffix}"
    }
  ]

  metric_widgets = {
    for c in local.columns : c.region => concat(
      [
        {
          title = "Success rate (%) - ${c.region}"
          metrics = [
            [{ expression = "100 - 100 * (FILL(elb5xx, 0) + FILL(tgt5xx, 0)) / requests", label = "Success %", id = "success" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", c.alb, { id = "elb5xx", stat = "Sum", visible = false }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", c.alb, { id = "tgt5xx", stat = "Sum", visible = false }],
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", c.alb, { id = "requests", stat = "Sum", visible = false }],
          ]
          annotations = { horizontal = [{ label = "SLO ${var.success_slo_percent}%", value = var.success_slo_percent }] }
        },
        {
          title = "Target response time (s) - ${c.region}"
          metrics = [
            for p in var.latency_percentiles :
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", c.alb, { stat = p, label = p }]
          ]
          annotations = { horizontal = [{ label = "SLO ${var.latency_threshold_seconds * 1000} ms", value = var.latency_threshold_seconds }] }
        },
        {
          title   = "Requests - ${c.region}"
          metrics = [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", c.alb, { stat = "Sum" }]]
        },
        {
          title = "5xx errors - ${c.region}"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", c.alb, { stat = "Sum", label = "ELB 5xx" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", c.alb, { stat = "Sum", label = "Target 5xx" }],
          ]
        },
        {
          title = "Targets - ${c.region}"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", c.target_group, "LoadBalancer", c.alb, { stat = "Minimum", label = "Healthy" }],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", c.target_group, "LoadBalancer", c.alb, { stat = "Maximum", label = "Unhealthy" }],
          ]
        },
        {
          title   = "Running tasks - ${c.region}"
          metrics = [["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", c.cluster, "ServiceName", c.service, { stat = "Minimum" }]]
        },
        {
          title = "ECS CPU and memory (%) - ${c.region}"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", c.cluster, "ServiceName", c.service, { stat = "Average", label = "CPU" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", c.cluster, "ServiceName", c.service, { stat = "Average", label = "Memory" }],
          ]
        },
      ],
      var.include_waf_widget ? [
        {
          title = "WAF requests - ${c.region}"
          metrics = concat(
            [["AWS/WAFV2", "AllowedRequests", "WebACL", c.web_acl, "Region", c.region, "Rule", "ALL", { stat = "Sum", label = "Allowed" }]],
            [for rule in var.waf_rule_metric_names : ["AWS/WAFV2", "CountedRequests", "WebACL", c.web_acl, "Region", c.region, "Rule", rule, { stat = "Sum", label = "Counted: ${rule}" }]],
          )
        },
      ] : [],
    )
  }

  widgets = flatten([
    for c in local.columns : concat(
      [{
        type       = "text"
        x          = c.x
        y          = 0
        width      = local.column_width
        height     = 1
        properties = { markdown = "## ${c.region}" }
      }],
      [
        for i, w in local.metric_widgets[c.region] : {
          type   = "metric"
          x      = c.x
          y      = 1 + i * var.widget_height
          width  = local.column_width
          height = var.widget_height
          properties = merge(
            {
              title   = w.title
              view    = "timeSeries"
              stacked = false
              region  = c.region
              period  = var.period
              metrics = w.metrics
            },
            contains(keys(w), "annotations") ? { annotations = w.annotations } : {},
          )
        }
      ],
    )
  ])
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.dashboard_name
  dashboard_body = jsonencode({ widgets = local.widgets })
}
