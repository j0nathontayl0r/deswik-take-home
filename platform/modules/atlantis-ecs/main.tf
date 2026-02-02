terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

resource "aws_security_group" "atlantis_alb" {
  name        = "${var.name_prefix}-atlantis-alb"
  description = "Security group for Atlantis ALB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis-alb"
    }
  )
}

resource "aws_security_group" "atlantis_tasks" {
  name        = "${var.name_prefix}-atlantis-tasks"
  description = "Security group for Atlantis ECS tasks"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS outbound for GitHub and AWS APIs"
  }

  egress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "NFS to EFS"
  }

  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
    description = "Redis to ElastiCache"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis-tasks"
    }
  )
}

resource "aws_security_group" "efs" {
  name        = "${var.name_prefix}-atlantis-efs"
  description = "Security group for Atlantis EFS"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.atlantis_tasks.id]
    description     = "NFS from Atlantis tasks"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis-efs"
    }
  )
}

resource "aws_efs_file_system" "atlantis" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}

resource "aws_efs_mount_target" "atlantis" {
  for_each        = toset(var.private_subnet_ids)
  file_system_id  = aws_efs_file_system.atlantis.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "atlantis" {
  file_system_id = aws_efs_file_system.atlantis.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/atlantis"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}

resource "aws_security_group" "redis" {
  name        = "${var.name_prefix}-atlantis-redis"
  description = "Security group for Atlantis Redis"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.atlantis_tasks.id]
    description     = "Redis from Atlantis tasks"
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis-redis"
    }
  )
}

resource "aws_elasticache_subnet_group" "atlantis" {
  name       = "${var.name_prefix}-atlantis"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}

resource "aws_elasticache_replication_group" "atlantis" {
  replication_group_id = "${var.name_prefix}-atlantis"
  description          = "Redis for Atlantis distributed locking"

  engine               = "redis"
  engine_version       = "7.1"
  node_type            = "cache.t4g.micro"
  num_cache_clusters   = 2
  parameter_group_name = "default.redis7"
  port                 = 6379

  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  subnet_group_name  = aws_elasticache_subnet_group.atlantis.name
  security_group_ids = [aws_security_group.redis.id]

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}

resource "aws_security_group_rule" "alb_to_oauth2_proxy_egress" {
  type                     = "egress"
  from_port                = 4180
  to_port                  = 4180
  protocol                 = "tcp"
  security_group_id        = aws_security_group.atlantis_alb.id
  source_security_group_id = aws_security_group.atlantis_tasks.id
  description              = "ALB to OAuth2 Proxy"
}

resource "aws_lb" "atlantis" {
  name               = "${var.name_prefix}-atlantis"
  internal           = var.internal_lb
  load_balancer_type = "application"
  security_groups    = [aws_security_group.atlantis_alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection

  access_logs {
    bucket  = var.lb_access_logs_bucket
    prefix  = var.lb_access_logs_prefix != "" ? var.lb_access_logs_prefix : "atlantis/${var.name_prefix}"
    enabled = var.lb_access_logs_bucket != ""
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}

resource "aws_lb_target_group" "atlantis" {
  name        = "${var.name_prefix}-atlantis"
  port        = 4180
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200-399"
    path                = "/ping"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}

resource "aws_lb_listener" "atlantis_https" {
  load_balancer_arn = aws_lb.atlantis.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.atlantis.arn
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "atlantis" {
  name              = "/ecs/${var.name_prefix}-atlantis"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.name_prefix}-atlantis-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis-ecs-task-execution"
    }
  )
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "secrets_access" {
  name = "secrets-access"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = concat(
          [
            var.github_token_secret_arn,
            var.github_webhook_secret_arn,
            var.redis_auth_token_secret_arn
          ],
        )
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${var.name_prefix}-atlantis-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis-ecs-task"
    }
  )
}

# Policy to allow Atlantis to assume roles across accounts
resource "aws_iam_role_policy" "assume_role" {
  name = "assume-role"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = var.allowed_assume_role_arns
      }
    ]
  })
}

# Policy to allow EFS access
resource "aws_iam_role_policy" "efs_access" {
  name = "efs-access"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = aws_efs_file_system.atlantis.arn
        Condition = {
          StringEquals = {
            "elasticfilesystem:AccessPointArn" = aws_efs_access_point.atlantis.arn
          }
        }
      }
    ]
  })
}

# Policy to allow ECS Exec (SSM session manager)
resource "aws_iam_role_policy" "ecs_exec" {
  name = "ecs-exec"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_ecs_task_definition" "atlantis" {
  family                   = "${var.name_prefix}-atlantis"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = local.container_definitions

  # if you need to update the task def for Atlantis, you must do so manually by running:
  # terraform plan -replace="module.atlantis[0].aws_ecs_task_definition.atlantis" -out=replace-atlantis-tasks && terraform apply "replace-atlantis-tasks"
  # Reason for ignoring the task definition is it means Atlantis could end up replacing Atlantis tasks while an apply is being ran, never a good thing.
  # So if Atlantis needs to be updated I recommend you do this locally, or alternatively consider moving the task definition to a different repo, but that seems overkill at time of writing.
  lifecycle {
    ignore_changes = [container_definitions]
  }

  volume {
    name = "atlantis-data"
    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.atlantis.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.atlantis.id
        iam             = "ENABLED"
      }
    }
  }

  ephemeral_storage {
    size_in_gib = 100
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )
}
resource "aws_ecs_service" "atlantis" {
  name            = "${var.name_prefix}-atlantis"
  cluster         = var.ecs_cluster_id
  task_definition = aws_ecs_task_definition.atlantis.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.atlantis_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.atlantis.arn
    container_name   = "oauth2-proxy"
    container_port   = 4180
  }

  enable_execute_command = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-atlantis"
    }
  )

  depends_on = [
    aws_lb_listener.atlantis_https
  ]
}

# Scheduled scaling for cost optimization
resource "aws_appautoscaling_target" "atlantis" {
  count              = var.enable_scheduled_scaling ? 1 : 0
  max_capacity       = 1
  min_capacity       = 0
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.atlantis.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scale up to 1 task at 08:00 AEST Monday-Friday
resource "aws_appautoscaling_scheduled_action" "atlantis_scale_up" {
  count              = var.enable_scheduled_scaling ? 1 : 0
  name               = "${var.name_prefix}-atlantis-scale-up"
  service_namespace  = aws_appautoscaling_target.atlantis[0].service_namespace
  resource_id        = aws_appautoscaling_target.atlantis[0].resource_id
  scalable_dimension = aws_appautoscaling_target.atlantis[0].scalable_dimension
  schedule           = "cron(0 21 ? * SUN-THU *)" # 21:00 UTC = 08:00 AEST (next day)

  scalable_target_action {
    min_capacity = 1
    max_capacity = 1
  }
}

# Scale down to 0 tasks at 18:00 AEST Monday-Friday
resource "aws_appautoscaling_scheduled_action" "atlantis_scale_down" {
  count              = var.enable_scheduled_scaling ? 1 : 0
  name               = "${var.name_prefix}-atlantis-scale-down"
  service_namespace  = aws_appautoscaling_target.atlantis[0].service_namespace
  resource_id        = aws_appautoscaling_target.atlantis[0].resource_id
  scalable_dimension = aws_appautoscaling_target.atlantis[0].scalable_dimension
  schedule           = "cron(0 7 ? * MON-FRI *)" # 07:00 UTC = 18:00 AEST

  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
