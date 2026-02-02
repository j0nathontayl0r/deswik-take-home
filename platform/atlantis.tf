locals {
  deploy_atlantis          = try(local.workspace.atlantis.enabled, false)
  atlantis_config          = try(local.workspace.atlantis, {})
  atlantis_cluster_name    = try(local.atlantis_config.cluster_name, "")
  atlantis_ecs_cluster_id  = local.deploy_atlantis && local.atlantis_cluster_name != "" ? module.ecs_cluster[local.atlantis_cluster_name].ecs_name : ""
  atlantis_datadog_enabled = try(local.atlantis_config.datadog_enabled, try(local.workspace.datadog_agent.enabled, false))
}

resource "aws_secretsmanager_secret" "atlantis_github_token" {
  count = local.deploy_atlantis ? 1 : 0

  name        = "/${local.workspace.org_name}/${local.workspace.account_name}/ATLANTIS_GITHUB_TOKEN"
  description = "GitHub Personal Access Token for Atlantis"

  tags = {
    Name        = "atlantis-github-token"
    Environment = local.workspace.account_name
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret" "atlantis_webhook_secret" {
  count = local.deploy_atlantis ? 1 : 0

  name        = "/${local.workspace.org_name}/${local.workspace.account_name}/ATLANTIS_WEBHOOK_SECRET"
  description = "GitHub Webhook Secret for Atlantis"

  tags = {
    Name        = "atlantis-webhook-secret"
    Environment = local.workspace.account_name
    ManagedBy   = "terraform"
  }
}

resource "random_password" "atlantis_redis" {
  count = local.deploy_atlantis ? 1 : 0

  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "atlantis_redis_password" {
  count = local.deploy_atlantis ? 1 : 0

  name        = "/${local.workspace.org_name}/${local.workspace.account_name}/ATLANTIS_REDIS_PASSWORD"
  description = "Redis Password for Atlantis"

  tags = {
    Name        = "atlantis-redis-password"
    Environment = local.workspace.account_name
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "atlantis_redis_password" {
  count = local.deploy_atlantis ? 1 : 0

  secret_id     = aws_secretsmanager_secret.atlantis_redis_password[0].id
  secret_string = random_password.atlantis_redis[0].result
}


resource "aws_secretsmanager_secret" "atlantis_oauth2_client_id" {
  count = local.deploy_atlantis && try(local.atlantis_config.oauth2_enabled, false) ? 1 : 0

  name        = "/${local.workspace.org_name}/${local.workspace.account_name}/ATLANTIS_OAUTH2_CLIENT_ID"
  description = "OAuth2 Client ID for Atlantis (Okta OIDC)"

  tags = {
    Name        = "atlantis-oauth2-client-id"
    Environment = local.workspace.account_name
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret" "atlantis_oauth2_client_secret" {
  count = local.deploy_atlantis && try(local.atlantis_config.oauth2_enabled, false) ? 1 : 0

  name        = "/${local.workspace.org_name}/${local.workspace.account_name}/ATLANTIS_OAUTH2_CLIENT_SECRET"
  description = "OAuth2 Client Secret for Atlantis (Okta OIDC)"

  tags = {
    Name        = "atlantis-oauth2-client-secret"
    Environment = local.workspace.account_name
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret" "atlantis_oauth2_cookie_secret" {
  count = local.deploy_atlantis && try(local.atlantis_config.oauth2_enabled, false) ? 1 : 0

  name        = "/${local.workspace.org_name}/${local.workspace.account_name}/ATLANTIS_OAUTH2_COOKIE_SECRET"
  description = "OAuth2 Cookie Secret for Atlantis (32-byte base64 encoded)"

  tags = {
    Name        = "atlantis-oauth2-cookie-secret"
    Environment = local.workspace.account_name
    ManagedBy   = "terraform"
  }
}

module "atlantis" {
  count = local.deploy_atlantis ? 1 : 0

  source = "./modules/atlantis-ecs"

  depends_on = [aws_secretsmanager_secret.secrets_manager]

  name_prefix        = "${local.workspace.org_name}-${local.workspace.account_name}"
  vpc_id             = data.aws_vpc.selected[0].id
  public_subnet_ids  = data.aws_subnets.public[0].ids
  private_subnet_ids = data.aws_subnets.private[0].ids
  ecs_cluster_id     = local.atlantis_ecs_cluster_id

  certificate_arn   = try(local.atlantis_config.certificate_arn, "")
  atlantis_hostname = try(local.atlantis_config.hostname, "")

  repo_allowlist = try(local.atlantis_config.repo_allowlist, "")
  github_user    = try(local.atlantis_config.github_user, "")

  github_token_secret_arn   = aws_secretsmanager_secret.atlantis_github_token[0].arn
  github_webhook_secret_arn = aws_secretsmanager_secret.atlantis_webhook_secret[0].arn

  allowed_assume_role_arns = try(local.atlantis_config.allowed_assume_role_arns, [])

  environment = local.workspace.environment

  atlantis_image = try(local.atlantis_config.image, "ghcr.io/runatlantis/atlantis:v0.37.0")
  cpu            = try(local.atlantis_config.cpu, 4096)
  memory         = try(local.atlantis_config.memory, 8192)
  desired_count  = try(local.atlantis_config.desired_count, 1)

  log_retention_days = try(tonumber(local.atlantis_config.log_retention_days), 30)

  enable_deletion_protection = try(local.atlantis_config.enable_deletion_protection, false)
  lb_access_logs_bucket      = try(local.atlantis_config.lb_access_logs_bucket, "")
  lb_access_logs_prefix      = local.workspace.account_name # Use account_name (stg/prod/dso) to match bucket policy

  extra_environment_variables = try(local.atlantis_config.extra_environment_variables, [])

  # Redis for distributed locking if HA over >1 AZ's is needed.
  redis_auth_token            = random_password.atlantis_redis[0].result
  redis_auth_token_secret_arn = aws_secretsmanager_secret.atlantis_redis_password[0].arn

  tags = {
    Name        = "atlantis"
    Environment = local.workspace.account_name
    ManagedBy   = "terraform"
    Stack       = "platform"
  }
}

data "aws_route53_zone" "atlantis" {
  count = local.deploy_atlantis && try(local.atlantis_config.create_dns_record, false) ? 1 : 0

  name         = try(local.atlantis_config.hosted_zone, "")
  private_zone = false
}

resource "aws_route53_record" "atlantis" {
  count = local.deploy_atlantis && try(local.atlantis_config.create_dns_record, false) ? 1 : 0

  zone_id = data.aws_route53_zone.atlantis[0].zone_id
  name    = try(local.atlantis_config.hostname, "")
  type    = "A"

  alias {
    name                   = module.atlantis[0].alb_dns_name
    zone_id                = module.atlantis[0].alb_zone_id
    evaluate_target_health = true
  }
}

output "atlantis_url" {
  description = "URL to access Atlantis"
  value       = local.deploy_atlantis ? "https://${local.atlantis_config.hostname}" : null
}

output "atlantis_alb_dns" {
  description = "ALB DNS name for Atlantis (use this for manual DNS configuration)"
  value       = local.deploy_atlantis ? module.atlantis[0].alb_dns_name : null
}

output "atlantis_webhook_url" {
  description = "Webhook URL to configure in GitHub repository settings"
  value       = local.deploy_atlantis ? "https://${local.atlantis_config.hostname}/events" : null
}

output "atlantis_github_token_secret_name" {
  description = "Name of the Secrets Manager secret for GitHub token (populate this manually)"
  value       = local.deploy_atlantis ? aws_secretsmanager_secret.atlantis_github_token[0].name : null
}

output "atlantis_webhook_secret_name" {
  description = "Name of the Secrets Manager secret for webhook secret (populate this manually)"
  value       = local.deploy_atlantis ? aws_secretsmanager_secret.atlantis_webhook_secret[0].name : null
}

output "atlantis_oauth2_client_id_secret_name" {
  description = "Name of the Secrets Manager secret for OAuth2 client ID (populate this manually)"
  value       = local.deploy_atlantis && try(local.atlantis_config.oauth2_enabled, false) ? aws_secretsmanager_secret.atlantis_oauth2_client_id[0].name : null
}

output "atlantis_oauth2_client_secret_secret_name" {
  description = "Name of the Secrets Manager secret for OAuth2 client secret (populate this manually)"
  value       = local.deploy_atlantis && try(local.atlantis_config.oauth2_enabled, false) ? aws_secretsmanager_secret.atlantis_oauth2_client_secret[0].name : null
}

output "atlantis_oauth2_cookie_secret_secret_name" {
  description = "Name of the Secrets Manager secret for OAuth2 cookie secret (populate this manually)"
  value       = local.deploy_atlantis && try(local.atlantis_config.oauth2_enabled, false) ? aws_secretsmanager_secret.atlantis_oauth2_cookie_secret[0].name : null
}
