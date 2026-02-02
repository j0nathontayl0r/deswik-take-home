locals {
  awslogs_config = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
      "awslogs-region"        = data.aws_region.current.name
      "awslogs-stream-prefix" = "placeholder"
    }
  }

  atlantis_repo_config = {
    repos = [
      {
        id                            = var.repo_allowlist
        allow_custom_workflows        = true
        allowed_overrides             = ["workflow", "apply_requirements"]
        delete_source_branch_on_merge = true
      }
    ]
  }

  oauth2_proxy_container = {
    name      = "oauth2-proxy"
    image     = var.oauth_image
    essential = true
    cpu       = 64
    memory    = 128
    portMappings = [
      {
        containerPort = 4180
        protocol      = "tcp"
      }
    ]
    environment = [
      { name = "OAUTH2_PROXY_HTTP_ADDRESS", value = "0.0.0.0:4180" },
      { name = "OAUTH2_PROXY_COOKIE_EXPIRE", value = "8h" },
      { name = "OAUTH2_PROXY_COOKIE_REFRESH", value = "1h" },
      { name = "OAUTH2_PROXY_UPSTREAMS", value = "http://127.0.0.1:4141" },
      { name = "OAUTH2_PROXY_PROVIDER", value = "oidc" },
      { name = "OAUTH2_PROXY_REDIRECT_URL", value = "https://${var.atlantis_hostname}/oauth2/callback" },
      { name = "OAUTH2_PROXY_COOKIE_SECURE", value = "true" },
      { name = "OAUTH2_PROXY_COOKIE_DOMAINS", value = var.atlantis_hostname },
      { name = "OAUTH2_PROXY_SKIP_PROVIDER_BUTTON", value = "true" },
      { name = "OAUTH2_PROXY_PASS_ACCESS_TOKEN", value = "true" },
      { name = "OAUTH2_PROXY_PASS_AUTHORIZATION_HEADER", value = "true" },
      { name = "OAUTH2_PROXY_SET_XAUTHREQUEST", value = "true" },
      { name = "OAUTH2_PROXY_REVERSE_PROXY", value = "true" },
      { name = "OAUTH2_PROXY_SKIP_AUTH_ROUTES", value = "^/events$|^/healthz$" },
      { name = "OAUTH2_PROXY_CODE_CHALLENGE_METHOD", value = "S256" },
    ]
    healthCheck = null
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "oauth2-proxy"
      }
    }
  }

  atlantis_base_environment = [
    { name = "TZ", value = "Australia/Brisbane" },
    { name = "GIT_CONFIG_COUNT", value = "1" },
    { name = "GIT_CONFIG_KEY_0", value = "safe.directory" },
    { name = "GIT_CONFIG_VALUE_0", value = "*" },
    { name = "ATLANTIS_PARALLEL_POOL_SIZE", value = "5" },
    { name = "TF_PLUGIN_CACHE_DIR", value = "/home/atlantis/.terraform.d/plugin-cache" },
    { name = "ATLANTIS_REPO_ALLOWLIST", value = var.repo_allowlist },
    { name = "ATLANTIS_ATLANTIS_URL", value = "https://${var.atlantis_hostname}" },
    { name = "ATLANTIS_PORT", value = "4141" },
    { name = "ATLANTIS_GH_USER", value = var.github_user },
    { name = "AWS_ENVIRONMENT", value = var.environment },
    { name = "ATLANTIS_REPO_CONFIG_JSON", value = jsonencode(local.atlantis_repo_config) },
    { name = "ATLANTIS_WRITE_GIT_CREDS", value = "true" },
    { name = "ATLANTIS_HIDE_PREV_PLAN_COMMENTS", value = "true" },
    { name = "ATLANTIS_DATA_DIR", value = "/home/atlantis" },
  ]

  atlantis_container = {
    name      = "atlantis"
    image     = var.atlantis_image
    essential = true
    cpu       = var.cpu
    memory    = var.memory
    portMappings = [
      {
        containerPort = 4141
        protocol      = "tcp"
      }
    ]
    environment = concat(local.atlantis_base_environment, var.extra_environment_variables)
    secrets = [
      { name = "ATLANTIS_GH_TOKEN", valueFrom = var.github_token_secret_arn },
      { name = "ATLANTIS_GH_WEBHOOK_SECRET", valueFrom = var.github_webhook_secret_arn },
    ]
    dockerLabels = {
    }
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.atlantis.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "atlantis"
      }
    }
    mountPoints = [
      {
        sourceVolume  = "atlantis-data"
        containerPath = "/home/atlantis"
        readOnly      = false
      }
    ]
    volumesFrom      = []
    healthCheck      = null
    entryPoint       = []
    command          = []
    user             = null
    workingDirectory = null
  }

  container_definitions = jsonencode([
    local.oauth2_proxy_container,
    local.atlantis_container,
  ])
}
