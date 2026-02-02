# Root justfile for msh-infra

# Generate atlantis.yaml from workspace configs
generate-atlantis:
    ./scripts/generate-atlantis-yaml.sh

# Check if atlantis.yaml is up to date
check-atlantis:
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/generate-atlantis-yaml.sh
    if ! git diff --quiet atlantis.yaml; then
        echo "ERROR: atlantis.yaml is out of date. Run 'just generate-atlantis'"
        git diff atlantis.yaml
        exit 1
    fi

# Format all terraform files across all stacks
fmt:
    terraform fmt -recursive network/
    terraform fmt -recursive platform/
