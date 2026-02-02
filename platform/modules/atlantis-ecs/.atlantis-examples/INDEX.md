# Atlantis Configuration Examples - INDEX

## Documentation Files

### Quick References

1. **[TOGGLE-REFERENCE.md](./TOGGLE-REFERENCE.md)** START HERE
   → Quick guide on using `atlantis.enabled: true/false`

2. **[README.md](./README.md)**
   → Overview of how the enable/disable toggle works

3. **[ARCHITECTURE.md](./ARCHITECTURE.md)**
   → Visual diagrams and architecture flow

### Example Configurations

1. **[ENABLED-jdtay-prd.yaml](./ENABLED-staging.yaml)**
   → Example with Atlantis enabled (for staging)
## Quick Answers

### "How do I enable Atlantis in a workspace?"

Add to your workspace YAML:

```yaml
atlantis:
  enabled: true
  # ... see ENABLED-staging.yaml for full config
```

### "How do I disable Atlantis in a workspace?"

**Option 1:** Don't include the `atlantis` block at all (recommended)

**Option 2:** Explicitly set `enabled: false`

```yaml
atlantis:
  enabled: false
```

### "Where should I enable Atlantis?"

Only in these 2 workspaces:

- `jdtay-stg-ap-southeast-2-default.yaml`
- `jdtay-prod-ap-southeast-2-default.yaml`

All other workspaces:  Leave disabled (no atlantis block)

### "What happens when I set enabled: true?"

Terraform creates ~23 resources:

- ECS Fargate service
- Application Load Balancer
- Security groups
- IAM roles
- CloudWatch log group
- Secrets Manager placeholders
- Route53 DNS record (optional)

Cost: ~$40-55/month per instance

### "What happens when I set enabled: false or omit the block?"

Terraform creates **zero** Atlantis resources.

Cost: **$0**

## File Structure

```text
platform/workspaces/
├── .atlantis-examples/           ← You are here
│   ├── INDEX.md                  ← This file
│   ├── TOGGLE-REFERENCE.md       ← Start here
│   ├── README.md                 ← Overview
│   ├── ARCHITECTURE.md           ← Diagrams
│   ├── ENABLED-staging.yaml      ← Example: enabled
│   ├── DISABLED-dev.yaml         ← Example: disabled (no block)
│   └── DISABLED-devsecops.yaml   ← Example: disabled (explicit)
├── atlantis-config-example.yaml  ← Full config template
├── jdtay-stg-ap-southeast-2-default.yaml   ← Your actual staging config
├── jdtay-prod-ap-southeast-2-default.yaml  ← Your actual prod config
└── jdtay-dev-ap-southeast-2-default.yaml   ← Your actual dev config
```

## Related Documentation

- **Full setup guide:** `_docs/ATLANTIS-SETUP.md`
- **Quick start:** `_docs/ATLANTIS-QUICKSTART.md`
- **Terraform implementation:** `platform/atlantis.tf`
- **Module code:** `platform/modules/atlantis-ecs/`
- **Root config:** `atlantis.yaml` (repo root)

## Common Questions

**Q: Can I enable Atlantis in multiple workspaces?**
A: Yes, but you only need 2 instances (staging + production).
   Both can manage all accounts.

**Q: Will enabling Atlantis affect my other workspaces?**
A: No, each workspace is independent.
   `enabled: true` only affects that specific workspace.

**Q: What if I enable it by mistake in dev?**
A: Set `enabled: false` or remove the atlantis block.
   Run `terraform apply` to destroy the resources.

**Q: Can I test this without actually deploying?**
A: Yes! Run `make plan` to see what would be created without applying.

**Q: Does this work with existing GitHub Actions?**
A: Yes, you can run both in parallel during migration.
   Disable GitHub Actions once Atlantis is working.

## Tips

1. **Start with staging** - Deploy to `jdtay-stg-ap-southeast-2-default` first
2. **Test thoroughly** - Create test PRs to validate the workflow
3. **Then production** - Deploy to `jdtay-prod-ap-southeast-2-default` once confident
4. **Keep it simple** - Don't enable in other workspaces unless you
   have a specific need

## Getting Started

1. Read [TOGGLE-REFERENCE.md](./TOGGLE-REFERENCE.md)
2. Copy config from [ENABLED-staging.yaml](./ENABLED-staging.yaml)
3. Add to `jdtay-stg-ap-southeast-2-default.yaml`
4. Follow the deployment guide in `_docs/ATLANTIS-SETUP.md`
