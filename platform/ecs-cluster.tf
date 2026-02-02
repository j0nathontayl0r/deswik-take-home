resource "aws_iam_service_linked_role" "ecs" {
  count            = local.workspace.ecs.create_iam_service_linked_role ? 1 : 0
  aws_service_name = "ecs.amazonaws.com"
}

module "ecs_cluster" {
  for_each = { for cluster in local.workspace.ecs.clusters : cluster.name => cluster }
  source   = "./modules/aws-ecs-6.2.0"

  name                 = each.value.name
  instance_types       = try(each.value.instance_types, [])
  instance_volume_size = try(each.value.instance_volume_size, 40)
  architecture         = try(each.value.architecture, "x86_64")
  fargate_only         = each.value.fargate_only

  vpc_id             = data.aws_vpc.selected[0].id
  private_subnet_ids = data.aws_subnets.private[0].ids
  public_subnet_ids  = data.aws_subnets.public[0].ids
  secure_subnet_ids  = data.aws_subnets.secure[0].ids

  certificate_arn        = try(each.value.certificate_arn, "")
  extra_certificate_arns = try(each.value.extra_certificate_arns, [])

  on_demand_percentage = try(each.value.on_demand_percentage, 100)
  asg_min              = try(each.value.asg_min, 1)
  asg_max              = try(each.value.asg_max, 8)
  asg_target_capacity  = try(each.value.asg_target_capacity, 70)

  alarm_sns_topics                    = try([local.workspace.notifications_sns_topic_arn], [])
  alarm_alb_latency_anomaly_threshold = try(each.value.alarm_alb_latency_anomaly_threshold, 0)
  alarm_prefix                        = terraform.workspace

  alb_only                        = try(each.value.alb_only, true) # prevents creating cloudfront - see terraform-aws-ecs-app-front
  alb                             = try(each.value.alb, true)
  alb_http_listener               = try(each.value.alb_http_listener, true)
  alb_sg_allow_test_listener      = try(each.value.alb_sg_allow_test_listener, true)
  alb_sg_allow_egress_https_world = try(each.value.alb_sg_allow_egress_https_world, true)
  alb_enable_deletion_protection  = try(each.value.alb_enable_deletion_protection, false)
  alb_ssl_policy                  = try(each.value.alb_ssl_policy, "ELBSecurityPolicy-TLS13-1-2-Res-2021-06")
  alb_internal                    = try(each.value.alb_internal, false)
  alb_internal_ssl_policy         = try(each.value.alb_internal_ssl_policy, "ELBSecurityPolicy-TLS13-1-2-Res-2021-06")

  wafv2_enable                            = try(each.value.wafv2_enable, false)
  wafv2_managed_rule_groups               = try(each.value.wafv2_managed_rule_groups, [])
  security_group_ecs_nodes_outbound_cidrs = try(each.value.sg_ecs_nodes_outbound_vpc_only, false) ? [data.aws_vpc.selected[0].cidr_block] : ["0.0.0.0/0"]
  lb_access_logs_bucket                   = try(each.value.lb_access_logs_bucket, "")
  lb_access_logs_prefix                   = try(each.value.lb_logs_prefix, local.workspace.account_name)

  enable_schedule     = try(each.value.shutdown_schedule.enabled, false)
  schedule_cron_start = try(each.value.shutdown_schedule.cron_start, "")
  schedule_cron_stop  = try(each.value.shutdown_schedule.cron_stop, "")

  backup             = try(each.value.efs_backup, false)
  create_efs         = try(each.value.create_efs, false)
  container_insights = try(each.value.container_insights, false)
}
