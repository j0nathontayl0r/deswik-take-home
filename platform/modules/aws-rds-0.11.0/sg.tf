resource "aws_security_group" "rds_db" {
  name_prefix = "rds-${var.environment_name}-${var.name}"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = { for sg in var.allow_security_group_ids : sg.security_group_id => sg if sg.security_group_id != null }
    content {
      from_port       = var.port
      to_port         = var.port
      protocol        = "tcp"
      security_groups = [ingress.value.security_group_id]
      description     = try(ingress.value.description, "From ${ingress.value.security_group_id}")
    }
  }

  # Inline CIDR-based ingress to avoid mixing rule types
  dynamic "ingress" {
    for_each = toset(var.allow_cidrs)
    content {
      from_port   = var.port
      to_port     = var.port
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
      description = "From CIDR ${ingress.value}"
    }
  }

  dynamic "egress" {
    for_each = toset(var.allow_cidrs)
    content {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}