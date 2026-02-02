variable "name_prefix" {
  description = "Prefix for resource names (e.g., jdtay-stg, jdtay-prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where Atlantis will be deployed"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_cluster_id" {
  description = "ECS cluster ID where Atlantis will run"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "atlantis_hostname" {
  description = "Hostname for Atlantis (e.g., atlantis.stg.jdtay.com.au)"
  type        = string
}

variable "repo_allowlist" {
  description = "GitHub repository allowlist (e.g., github.com/get-jdtay/jdtay-infra)"
  type        = string
}

variable "github_user" {
  description = "GitHub username for Atlantis authentication"
  type        = string
  default     = ""
}

variable "github_token_secret_arn" {
  description = "ARN of Secrets Manager secret containing GitHub token"
  type        = string
}

variable "github_webhook_secret_arn" {
  description = "ARN of Secrets Manager secret containing GitHub webhook secret"
  type        = string
}

variable "allowed_assume_role_arns" {
  description = "List of IAM role ARNs that Atlantis can assume for deployments"
  type        = list(string)
}

variable "environment" {
  description = "Environment name (e.g., dso, stg, prd)"
  type        = string
}

variable "atlantis_image" {
  description = "Docker image for Atlantis"
  type        = string
  default     = "ghcr.io/runatlantis/atlantis:v0.37.0"
}

variable "oauth_image" {
  description = "Docker image for OAuth2 Proxy"
  type        = string
  default     = "quay.io/oauth2-proxy/oauth2-proxy:v7.13.0"
}

variable "cpu" {
  description = "CPU units for Atlantis task"
  type        = number
  default     = 4096
}

variable "memory" {
  description = "Memory (MB) for Atlantis task"
  type        = number
  default     = 8192
}

variable "desired_count" {
  description = "Desired number of Atlantis tasks"
  type        = number
  default     = 1
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling to reduce costs outside business hours (08:00-18:00 AEST Mon-Fri)"
  type        = bool
  default     = false
}

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster (required for scheduled scaling)"
  type        = string
  default     = ""
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on ALB"
  type        = bool
  default     = false
}

variable "lb_access_logs_bucket" {
  description = "S3 bucket for ALB access logs (empty string disables)"
  type        = string
  default     = ""
}

variable "internal_lb" {
  description = "Whether the ALB is internal"
  type        = bool
  default     = false
}

variable "lb_access_logs_prefix" {
  description = "S3 prefix for ALB access logs"
  type        = string
  default     = ""
}

variable "extra_environment_variables" {
  description = "Additional environment variables for Atlantis container"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "redis_auth_token" {
  description = "Auth token for Redis (must be 16-128 characters)"
  type        = string
  sensitive   = true
}

variable "redis_auth_token_secret_arn" {
  description = "ARN of Secrets Manager secret containing Redis auth token"
  type        = string
}
