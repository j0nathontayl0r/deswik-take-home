resource "aws_cloudwatch_log_group" "tasks_logs" {
  for_each          = { for task in try(local.workspace.ecs.tasks, []) : task.name => task }
  name              = "/ecs/${each.value.cluster_name}/${each.value.name}"
  retention_in_days = 120
  tags = {
    "ExportToS3" = "true"
  }
}