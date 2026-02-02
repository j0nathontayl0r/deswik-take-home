# Atlantis Workspace Configuration Examples

## Overview

The `atlantis.enabled` boolean in your workspace YAML controls whether Atlantis gets deployed to that environment.

## How It Works

In [platform/atlantis.tf](../../atlantis.tf):

```hcl
locals {
  # If atlantis.enabled is not set or false, this will be false
  deploy_atlantis = try(local.workspace.atlantis.enabled, false)
  atlantis_config = try(local.workspace.atlantis, {})
}

# All Atlantis resources use count to conditionally deploy
module "atlantis" {
  count = local.deploy_atlantis ? 1 : 0
  # ... module configuration
}
```

## Usage

### Enable Atlantis (2 workspaces only)

**Staging:** `jdtay-stg-ap-southeast-2-default.yaml`
```yaml
atlantis:
  enabled: true  # Deploy Atlantis here
  cluster_name: "jdtay-stg-cluster"
  hostname: "atlantis.stg.jdtay.com.au"
  # ... rest of config
```

**Production:** `jdtay-prod-ap-southeast-2-default.yaml`
```yaml
atlantis:
  enabled: true  # Deploy Atlantis here
  cluster_name: "jdtay-prod-cluster"
  hostname: "atlantis.prod.jdtay.com.au"
  # ... rest of config
```

### Disable Atlantis (all other workspaces)

**Option 1:** Omit the block entirely (recommended)
```yaml
# No atlantis block = Atlantis not deployed
aws_region: ap-southeast-2
aws_account_id: "231192882420"
org_name: jdtay
account_name: dev
# ...
```

**Option 2:** Explicitly set to false
```yaml
atlantis:
  enabled: false  # Atlantis not deployed
```

## Examples in This Directory

- **[ENABLED-staging.yaml](./ENABLED-staging.yaml)** - Atlantis enabled (staging)
- **[DISABLED-dev.yaml](./DISABLED-dev.yaml)** - Atlantis disabled (no block)
- **[DISABLED-devsecops.yaml](./DISABLED-devsecops.yaml)** - Atlantis disabled (explicit)

## When To Enable

**Enable Atlantis in:**
-  `jdtay-stg-ap-southeast-2-default` (staging testing instance)
-  `jdtay-prod-ap-southeast-2-default` (production instance)

**Do NOT enable in:**
-  `jdtay-dev-ap-southeast-2-default`
-  `jdtay-devsecops-ap-southeast-2-default`
-  `jdtay-shared-ap-southeast-2-default`
-  Any other workspace

## Why Only 2 Instances?

You only need Atlantis deployed in staging and production because:

1. **Staging** = Testing Atlantis configuration and workflows
2. **Production** = Production Atlantis for actual deployments

Both instances can manage **all** workspaces across **all** accounts via IAM role assumption. You don't need separate Atlantis instances per environment.

## What Gets Deployed

When `enabled: true`:
-  ECS Fargate service running Atlantis
-  Application Load Balancer with HTTPS
-  Security groups
-  IAM roles for cross-account access
-  CloudWatch log group
-  Secrets Manager secrets (you populate these manually)
-  Route53 DNS record (optional)

When `enabled: false` or omitted:
-  Nothing deployed
-  No cost incurred
-  No resources created

## Terraform Behavior

```bash
# Workspace WITH atlantis.enabled: true
$ cd platform
$ export WORKSPACE=jdtay-stg-ap-southeast-2-default
$ make plan
# Output shows Atlantis resources will be created

# Workspace WITHOUT atlantis block (or enabled: false)
$ export WORKSPACE=jdtay-dev-ap-southeast-2-default
$ make plan
# Output shows NO Atlantis resources (count = 0)
```

## Full Configuration Template

See [../atlantis-config-example.yaml](../atlantis-config-example.yaml) for all available options.
