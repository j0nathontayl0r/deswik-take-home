locals {
  stack_name     = "platform"
  client         = "jdtay"
  workspace_file = fileexists("./workspaces/${terraform.workspace}.yaml") ? "./workspaces/${terraform.workspace}.yaml" : "./workspaces/${sort(fileset("./workspaces", "*.yaml"))[0]}"
  workspace      = yamldecode(file(local.workspace_file))
  aws_role       = "CIDeployAccess"
}

provider "aws" {
  # re-enable these later when we've upgraded to v5 or v6 of the AWS provider, not supported on v4
  #retry_mode  = "adaptive"
  #max_retries = 10
  region = local.workspace.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${local.workspace.aws_account_id}:role/${local.aws_role}"
  }
}

provider "aws" {
  # re-enable these later when we've upgraded to v5 or v6 of the AWS provider, not supported on v4
  #retry_mode  = "adaptive"
  #max_retries = 10
  region = "us-east-1"
  alias  = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.workspace.aws_account_id}:role/${local.aws_role}"
  }
}
