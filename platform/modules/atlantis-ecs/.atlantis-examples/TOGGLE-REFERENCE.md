# Atlantis Enable/Disable Toggle Reference

## Quick Answer

**Yes, you have a top-level boolean to enable/disable Atlantis at the workspace level!**

It's already built into the implementation:

```yaml
atlantis:
  enabled: true   # Deploy Atlantis
  # OR
  enabled: false  # Don't deploy Atlantis
  # OR
  # (omit the atlantis block entirely to disable)
```

## How To Use

###  Enable Atlantis

Add to `jdtay-stg-ap-southeast-2-default.yaml` or `jdtay-prod-ap-southeast-2-default.yaml`:

```yaml
atlantis:
  enabled: true  # ← THE TOGGLE
  cluster_name: "jdtay-stg-cluster"
  hostname: "atlantis.stg.jdtay.com.au"
  certificate_arn: "arn:aws:acm:..."
  repo_allowlist: "github.com/get-jdtay/jdtay-infra"
  allowed_assume_role_arns:
    - "arn:aws:iam::123456789:role/AtlantisDeployRole"
  # ... rest of config
```

###  Disable Atlantis (Method 1 - Recommended)

Simply don't include the `atlantis` block in your workspace YAML:

```yaml
# jdtay-dev-ap-southeast-2-default.yaml
aws_region: ap-southeast-2
aws_account_id: "231192882420"
org_name: jdtay
account_name: dev

# No atlantis block = Atlantis disabled
```

###  Disable Atlantis (Method 2 - Explicit)

Add `enabled: false` to your workspace YAML:

```yaml
# jdtay-devsecops-ap-southeast-2-default.yaml
aws_region: ap-southeast-2
aws_account_id: "231192882420"
org_name: jdtay
account_name: devsecops

atlantis:
  enabled: false  # ← Explicitly disabled
```

## Where The Toggle Is Checked

In [platform/atlantis.tf](../../atlantis.tf):

```hcl
locals {
  # This reads atlantis.enabled from your workspace YAML
  # If not present or false, deploy_atlantis = false
  deploy_atlantis = try(local.workspace.atlantis.enabled, false)
}

# All Atlantis resources use this toggle via count
module "atlantis" {
  count = local.deploy_atlantis ? 1 : 0  # 1 = deploy, 0 = skip
  # ...
}

resource "aws_secretsmanager_secret" "atlantis_github_token" {
  count = local.deploy_atlantis ? 1 : 0  # Same toggle
  # ...
}

# All other Atlantis resources follow the same pattern
```

## Behavior

| `atlantis.enabled` Value | Resources Created | Cost    | Use Case               |
|-------------------------|-------------------|---------|------------------------|
| `true`                  |  All resources  | ~$40-55 | Staging/Production     |
| `false`                 |  Nothing        | $0      | Explicitly disabled    |
| (not set/omitted)       |  Nothing        | $0      | Implicitly disabled    |

## Examples

See the files in this directory:

- **[ENABLED-staging.yaml](./ENABLED-staging.yaml)** - Full example with Atlantis enabled
- **[DISABLED-dev.yaml](./DISABLED-dev.yaml)** - Example with no atlantis block
- **[DISABLED-devsecops.yaml](./DISABLED-devsecops.yaml)** - Example with explicit `enabled: false`
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Visual diagrams of how the toggle works

## Testing The Toggle

### Enable Atlantis

```bash
cd platform
export WORKSPACE=jdtay-stg-ap-southeast-2-default

# Edit workspace file and add:
# atlantis:
#   enabled: true
#   ...

make plan
#  You'll see Atlantis resources in the plan
```

### Disable Atlantis

```bash
cd platform
export WORKSPACE=jdtay-dev-ap-southeast-2-default

# Ensure workspace file has NO atlantis block
# OR has atlantis.enabled: false

make plan
#  You'll see NO Atlantis resources in the plan
```

## Toggling For An Existing Deployment

### To Disable Atlantis After It's Deployed

1. Edit workspace YAML:
```yaml
atlantis:
  enabled: false
```

2. Apply:
```bash
cd platform
export WORKSPACE=jdtay-stg-ap-southeast-2-default
make plan
# Shows: 23 resources to destroy
make apply
# Removes all Atlantis resources
```

### To Re-Enable Atlantis

1. Edit workspace YAML:
```yaml
atlantis:
  enabled: true
  # ... rest of config
```

2. Apply:
```bash
make plan
# Shows: 23 resources to add
make apply
# Deploys Atlantis again
```

## Summary

 **Yes, the toggle exists!**
 **It's workspace-level**
 **It's a simple boolean: `atlantis.enabled: true/false`**
 **It controls ALL Atlantis resources**
 **It's already implemented in `platform/atlantis.tf`**

No additional changes needed - it's ready to use!
