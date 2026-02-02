terraform {
  required_version = "~> 1.14.0"
  backend "s3" {
    bucket  = "jdtay-terraform-backend"
    key     = "platform"
    region  = "ap-southeast-2"
    encrypt = true
    # dynamodb_table = "terraform-lock"
    assume_role = {
      role_arn = "arn:aws:iam::231192882420:role/TerraformBackendAccess"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.44.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.0"
    }
  }
}
