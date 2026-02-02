output "alb_dns_name" {
  description = "DNS name of the Atlantis ALB"
  value       = aws_lb.atlantis.dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the Atlantis ALB"
  value       = aws_lb.atlantis.zone_id
}

output "alb_arn" {
  description = "ARN of the Atlantis ALB"
  value       = aws_lb.atlantis.arn
}

output "ecs_service_name" {
  description = "Name of the Atlantis ECS service"
  value       = aws_ecs_service.atlantis.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role (for Atlantis runtime permissions)"
  value       = aws_iam_role.ecs_task.arn
}

output "security_group_alb_id" {
  description = "Security group ID for Atlantis ALB"
  value       = aws_security_group.atlantis_alb.id
}

output "security_group_tasks_id" {
  description = "Security group ID for Atlantis ECS tasks"
  value       = aws_security_group.atlantis_tasks.id
}

output "log_group_name" {
  description = "CloudWatch log group name for Atlantis"
  value       = aws_cloudwatch_log_group.atlantis.name
}

output "target_group_arn" {
  description = "ARN of the Atlantis target group"
  value       = aws_lb_target_group.atlantis.arn
}
