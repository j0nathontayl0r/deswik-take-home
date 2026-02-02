terraform {
  required_version = "~> 1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.35.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.2.3"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
  backend "s3" {
    bucket  = "jdtay-terraform-backend"
    key     = "network"
    region  = "ap-southeast-2"
    encrypt = true
    assume_role = {
      role_arn = "arn:aws:iam::231192882420:role/TerraformBackendAccess"
    }
  }
}
