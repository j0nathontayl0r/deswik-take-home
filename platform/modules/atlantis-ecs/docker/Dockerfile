ARG ATLANTIS_VERSION=v0.37.0
FROM ghcr.io/runatlantis/atlantis:${ATLANTIS_VERSION}

USER root

RUN apk add --no-cache \
    tzdata \
    bash \
    curl \
    jq \
    git

ENV TZ=Australia/Brisbane

RUN mkdir -p /home/atlantis/.terraform.d/plugin-cache && \
    chown -R atlantis:atlantis /home/atlantis/.terraform.d

ENV TF_PLUGIN_CACHE_DIR=/home/atlantis/.terraform.d/plugin-cache

USER atlantis
WORKDIR /home/atlantis

RUN mkdir -p /tmp/provider-cache && \
    cd /tmp/provider-cache && \
    cat > versions.tf << 'EOF'
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6"
    }
  }
}
EOF
RUN cd /tmp/provider-cache && \
    terraform init -backend=false && \
    rm -rf /tmp/provider-cache

USER atlantis

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]
