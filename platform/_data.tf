data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  has_ecs_clusters     = length(try(local.workspace.ecs.clusters, [])) > 0
  has_eks_clusters     = try(local.workspace.eks.enabled, false)
  is_ci_deploy_enabled = try(local.workspace.gitlab_runner.ci_deploy.enabled, false)
  has_ec2_instance     = length(try(local.workspace.ec2, [])) > 0
  has_vpc              = (try(local.workspace.has_vpc, false) || local.has_eks_clusters || local.has_ecs_clusters || local.is_ci_deploy_enabled || local.has_ec2_instance)
}

data "aws_vpc" "selected" {
  count = local.has_vpc ? 1 : 0
  filter {
    name   = "tag:EnvName"
    values = [local.workspace.account_name]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_subnets" "public" {
  count = local.has_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected[0].id]
  }

  filter {
    name   = "tag:Scheme"
    values = ["public"]
  }
}

data "aws_subnets" "private" {
  count = local.has_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected[0].id]
  }

  filter {
    name   = "tag:Scheme"
    values = ["private"]
  }
}

data "aws_cloudformation_export" "network_db_subnet_group" {
  count = length(local.workspace.rds.dbs) > 0 ? 1 : 0
  name  = "TfExport-Network-${local.workspace.account_name}-DbSubnetGroupId"
}

data "aws_db_subnet_group" "selected" {
  count = length(local.workspace.rds.dbs) > 0 ? 1 : 0
  name  = data.aws_cloudformation_export.network_db_subnet_group[0].value
}

data "aws_subnets" "secure" {
  count = local.has_vpc ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected[0].id]
  }

  filter {
    name   = "tag:Scheme"
    values = ["secure"]
  }
}

data "aws_subnet" "private" {
  for_each = local.has_vpc ? toset(data.aws_subnets.private[0].ids) : toset([])
  id       = each.value
}

data "aws_subnet" "secure" {
  for_each = local.has_vpc ? toset(data.aws_subnets.secure[0].ids) : toset([])
  id       = each.value
}

data "aws_security_groups" "tailscale_security_groups" {
  count = try(local.workspace.tailscale.enabled, false) ? 1 : 0
  filter {
    name   = "tag:Name"
    values = ["${local.workspace.account_name}-tailscale-subnet-router"]
  }
}

data "aws_security_groups" "rds_client_vpn" {
  for_each = toset(flatten(try(local.workspace.rds.dbs[*].allow_from_client_vpns, [])))
  filter {
    name   = "tag:EnvName"
    values = [each.key]
  }
}

data "aws_ssm_parameter" "rds" {
  for_each = { for ssm in try(local.workspace.dms.endpoint, []) : ssm.endpoint_id => ssm }
  name     = each.value.ssm
}

# output "test" {
#   value = data.aws_security_groups.rds_client_vpn
# }
