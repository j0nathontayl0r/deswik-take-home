resource "aws_cloudwatch_dashboard" "main" {
  for_each       = { for cluster in local.workspace.ecs.cloudwatch_dashboards : cluster.name => cluster }
  dashboard_name = each.value.name
  dashboard_body = jsonencode({
    widgets = [for service_name in each.value.services : {
      type   = "metric"
      width  = 18
      height = 6
      properties = {
        view    = "timeSeries"
        stacked = false
        metrics = [
          ["AWS/ECS", "CPUUtilization", "ServiceName", service_name, "ClusterName", each.value.cluster_name, { color = "#d62728", stat = "Maximum" }],
          [".", "MemoryUtilization", ".", ".", ".", ".", { yAxis = "right", color = "#1f77b4", stat = "Maximum" }]
        ]
        region = local.workspace.aws_region,
        annotations = {
          horizontal = [
            {
              color = "#ff9896",
              label = "100% CPU",
              value = 100
            },
            {
              color = "#9edae5",
              label = "100% Memory",
              value = 100,
              yAxis = "right"
            },
          ]
        }
        yAxis = {
          left = {
            min = 0
          }
          right = {
            min = 0
          }
        }
        title  = "${each.value.cluster_name} / ${service_name}"
        period = 300
      }
    }]
  })
  lifecycle {
    ignore_changes = [dashboard_body]
  }
}


