# Atlantis ECS Module

<!-- markdownlint-disable MD013 -->

This module deploys [Atlantis](https://www.runatlantis.io/) on AWS ECS Fargate for
managing Terraform workflows via GitOps.

## Features

- **ECS Fargate deployment** - Serverless, no EC2 instance management
- **Application Load Balancer** - HTTPS endpoint with health checks
- **IAM role assumption** - Atlantis can assume roles across AWS accounts
- **Secrets management** - GitHub tokens stored in AWS Secrets Manager
- **CloudWatch logging** - Centralized log management
- **Security groups** - Network isolation for ALB and ECS tasks

## Usage

```hcl
module "atlantis" {
  source = "./modules/atlantis-ecs"

  name_prefix        = "jdtay-stg"
  vpc_id             = data.aws_vpc.selected.id
  public_subnet_ids  = data.aws_subnet_ids.public.ids
  private_subnet_ids = data.aws_subnet_ids.private.ids
  ecs_cluster_id     = module.ecs_cluster["jdtay-stg-cluster"].ecs_cluster_id

  certificate_arn    = "arn:aws:acm:ap-southeast-2:123456789:certificate/abc..."
  atlantis_hostname  = "atlantis.stg.jdtay.com.au"

  repo_allowlist     = "github.com/get-jdtay/jdtay-infra"
  github_user        = "get-jdtay-bot"  # GitHub username

  github_token_secret_arn    = aws_secretsmanager_secret.atlantis_github_token.arn
  github_webhook_secret_arn  = aws_secretsmanager_secret.atlantis_webhook_secret.arn

  allowed_assume_role_arns = [
    "arn:aws:iam::231192882420:role/AtlantisDeployRole",  # staging
    "arn:aws:iam::231192882420:role/AtlantisDeployRole",  # production
    "arn:aws:iam::231192882420:role/AtlantisDeployRole",  # audit
  ]

  tags = {
    Environment = "staging"
    ManagedBy   = "terraform"
  }
}
```

## Prerequisites

1. **GitHub Personal Access Token** - Store in AWS Secrets Manager with permissions:
   - `repo` (full control)
   - `admin:repo_hook` (webhook management)

2. **GitHub Webhook Secret** - Random string stored in AWS Secrets Manager

3. **IAM Roles** - Create `AtlantisDeployRole` in each target AWS account

4. **DNS** - Create Route53 record pointing to the ALB

5. **Certificate** - ACM certificate for your Atlantis domain

6. **CloudWatch Logs** - Atlantis logs are sent to CloudWatch Logs by default

## Security Considerations

- ALB accepts HTTPS only (port 443)
- ECS tasks run in private subnets
- Secrets are stored in AWS Secrets Manager
- Network traffic is restricted via security groups
- IAM role assumption is limited to specified accounts

## Outputs

- `alb_dns_name` - DNS name for creating Route53 alias
- `ecs_service_name` - For monitoring and debugging
- `log_group_name` - For viewing Atlantis logs

## Notes

- Atlantis runs a single task by default (stateless design)
- Health check endpoint: `/healthz`
- Container port: 4141
- Logs retention: 30 days (configurable)

## Cost Estimates

Estimated monthly costs for ap-southeast-2 (Sydney) region:

| Resource | Specification | Estimated Monthly Cost (USD) |
|----------|---------------|------------------------------|
| **ECS Fargate** | 4 vCPU, 8 GB memory, 24/7 | ~$145 |
| **EFS (Bursting)** | ~1 GB storage | ~$0.50 |
| **ElastiCache Redis** | 2x cache.t4g.micro (Multi-AZ) | ~$24 |
| **ALB** | 1 ALB + LCUs | ~$20-30 |
| **Secrets Manager** | 4-5 secrets | ~$2 |
| **CloudWatch Logs** | ~5 GB/month ingestion | ~$3 |
| **NAT Gateway** | Data transfer (shared) | Variable |
| **Total (approx.)** | | **~$195-205/month** |

**Notes:**

- Costs assume 24/7 uptime with single task
- EFS uses bursting throughput mode (sufficient for current workload)
- Redis uses reserved capacity pricing if available
- Actual costs may vary based on usage patterns and data transfer

## Scheduled Scaling

The module supports scheduled scaling to reduce costs outside business hours.

### Configuration

```hcl
module "atlantis" {
  # ... other config ...

  enable_scheduled_scaling = true
  ecs_cluster_name         = "jdtay-dso-cluster"  # Required for scaling
}
```

### Schedule (AEST)

| Time | Action | Days |
|------|--------|------|
| 08:00 | Scale to 1 task | Monday - Friday |
| 18:00 | Scale to 0 tasks | Monday - Friday |

**Note:** Weekends run at 0 tasks.

### On-Demand Scaling Recommendations

When Atlantis is scaled to 0, incoming webhooks will fail. Consider these approaches to
scale up on-demand:

1. **GitHub Actions Workflow** (Recommended)
   - Trigger on `pull_request` events (opened, reopened, synchronize)
   - Use AWS CLI to update ECS service desired count
   - Example: `aws ecs update-service --cluster $CLUSTER --service $SERVICE --desired-count 1`
   - Pros: Native GitHub integration, no additional infrastructure
   - Cons: Adds ~60-90 seconds latency for first plan

2. **API Gateway + Lambda**
   - Create a Lambda that scales ECS when invoked
   - Configure as a secondary GitHub webhook endpoint
   - Lambda scales up, then forwards webhook to Atlantis once healthy
   - Pros: Works with any Git provider, can add retry logic
   - Cons: More infrastructure to maintain

3. **EventBridge + Step Functions**
   - EventBridge receives webhook, triggers Step Function
   - Step Function: scale ECS → wait for healthy → forward webhook
   - Pros: Built-in retry/wait logic, good observability
   - Cons: More complex setup

4. **ALB Request-Based Scaling** (Not viable)
   - ECS auto-scaling on ALB requests won't work as requests fail when at 0 tasks

**Suggested GitHub Actions approach:**

```yaml
# .github/workflows/wake-atlantis.yml
name: Wake Atlantis
on:
  pull_request:
    types: [opened, reopened, synchronize]

jobs:
  wake:
    runs-on: ubuntu-latest
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
          aws-region: ap-southeast-2
      - run: |
          aws ecs update-service \
            --cluster jdtay-dso-cluster \
            --service jdtay-dso-atlantis \
            --desired-count 1
          # Wait for task to be running
          aws ecs wait services-stable \
            --cluster jdtay-dso-cluster \
            --services jdtay-dso-atlantis
```

## Custom Atlantis Image

A custom Atlantis Docker image is provided in `docker/Dockerfile` with the following
enhancements:

- **Timezone support** - `tzdata` package installed, `TZ` env var works correctly
- **Plugin cache** - Directory pre-created at `/home/atlantis/.terraform.d/plugin-cache`
- **Pre-cached providers** - AWS, random, tls, archive providers pre-downloaded
- **Additional tools** - bash, curl, jq for debugging

### Using the Custom Image

Update the workspace configuration:

```yaml
atlantis:
  image: "ghcr.io/get-jdtay/atlantis:v0.37.0"
```

## Potential improvements

1. Atlantis is not in HA - there's only ever 1x task. This is fine for current needs but may need adjustment later.
2. Implement on-demand scaling via GitHub Actions to wake Atlantis when PRs are created.
