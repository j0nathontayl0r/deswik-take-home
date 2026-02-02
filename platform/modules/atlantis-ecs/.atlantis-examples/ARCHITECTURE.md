# Atlantis Enabled/Disabled Architecture

## How the Toggle Works

```text
┌─────────────────────────────────────────────────────────────────┐
│                    WORKSPACE YAML FILES                          │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│  jdtay-stg-...yaml        │  │  jdtay-prod-...yaml       │
│                          │  │                          │
│  atlantis:               │  │  atlantis:               │
│    enabled: true       │  │    enabled: true       │
│    cluster_name: ...     │  │    cluster_name: ...     │
│    hostname: ...         │  │    hostname: ...         │
└────────────┬─────────────┘  └────────────┬─────────────┘
             │                             │
             │                             │
   ┌─────────────────────────────────────────────────┐
   │  jdtay-dev-...yaml                               │
   │  jdtay-devsecops-...yaml                         │
   │  jdtay-shared-...yaml                            │
   │                                                  │
   │  (no atlantis block)                          │
   │  OR atlantis.enabled: false                   │
   └─────────────────┬───────────────────────────────┘
                     │
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                 TERRAFORM LOGIC (platform/atlantis.tf)           │
│                                                                  │
│  locals {                                                        │
│    deploy_atlantis = try(local.workspace.atlantis.enabled, false)│
│    atlantis_config = try(local.workspace.atlantis, {})          │
│  }                                                               │
│                                                                  │
│  module "atlantis" {                                             │
│    count = local.deploy_atlantis ? 1 : 0  ← THE MAGIC           │
│    ...                                                           │
│  }                                                               │
└─────────────────────────────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
        ▼                         ▼
┌──────────────────┐    ┌──────────────────┐
│  count = 1       │    │  count = 0       │
│   DEPLOY       │    │   SKIP         │
└──────────────────┘    └──────────────────┘
        │                         │
        ▼                         ▼
┌──────────────────┐    ┌──────────────────┐
│ STAGING ATLANTIS │    │   NO RESOURCES   │
│                  │    │                  │
│ • ECS Service    │    │ (Nothing created)│
│ • ALB            │    │                  │
│ • IAM Roles      │    │ Cost: $0         │
│ • Security Groups│    │                  │
│ • DNS Record     │    │                  │
│                  │    │                  │
│ Cost: ~$40/mo    │    │                  │
└──────────────────┘    └──────────────────┘

┌──────────────────┐
│ PROD ATLANTIS    │
│                  │
│ • ECS Service    │
│ • ALB            │
│ • IAM Roles      │
│ • Security Groups│
│ • DNS Record     │
│                  │
│ Cost: ~$55/mo    │
└──────────────────┘
```

## Configuration Matrix

| Workspace                              | `atlantis.enabled` | Resources Deployed? | Cost    |
|----------------------------------------|-------------------|---------------------|---------|
| `jdtay-prod-ap-southeast-2-default`     | `true`          | YES                 | ~$55/mo |

## Code Flow

```hcl
# 1. In your workspace YAML
atlantis:
  enabled: true  # <-- This is the control switch

# 2. In platform/atlantis.tf
locals {
  # Reads atlantis.enabled from workspace YAML (defaults to false)
  deploy_atlantis = try(local.workspace.atlantis.enabled, false)
}

# 3. Conditional resource creation
module "atlantis" {
  count = local.deploy_atlantis ? 1 : 0  # If true → 1, if false → 0

  # When count = 0, module is not instantiated at all
  # When count = 1, module creates all resources
}

resource "aws_secretsmanager_secret" "atlantis_github_token" {
  count = local.deploy_atlantis ? 1 : 0  # Same pattern
}

resource "aws_route53_record" "atlantis" {
  count = local.deploy_atlantis ? 1 : 0  # Same pattern
}
```

## What Happens During `terraform plan`

### Workspace WITH `atlantis.enabled: true`

```bash
$ export WORKSPACE=jdtay-stg-ap-southeast-2-default
$ make plan

Terraform will perform the following actions:

  # module.atlantis[0].aws_lb.atlantis will be created
  # module.atlantis[0].aws_ecs_service.atlantis will be created
  # module.atlantis[0].aws_security_group.atlantis_alb will be created
  # ... (many resources)

Plan: 23 to add, 0 to change, 0 to destroy.
```

### Workspace WITHOUT atlantis block

```bash
$ export WORKSPACE=jdtay-dev-ap-southeast-2-default
$ make plan

# Atlantis resources not shown (count = 0 means they're skipped)

Plan: 0 to add, 0 to change, 0 to destroy.
```

## Summary

- **One toggle:** `atlantis.enabled: true/false`
- **One location:** Workspace YAML file
- **Two instances:** Staging + Production only
- **Zero overhead:** All other workspaces cost $0 (nothing deployed)
- **Simple logic:** Terraform `count` meta-argument handles everything
