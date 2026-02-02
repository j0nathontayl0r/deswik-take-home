locals {
  stack_name     = "network"
  client         = "jdtay"
  workspace_file = fileexists("./workspaces/${terraform.workspace}.yaml") ? "./workspaces/${terraform.workspace}.yaml" : "./workspaces/${sort(fileset("./workspaces", "*.yaml"))[0]}"
  workspace      = yamldecode(file(local.workspace_file))
  aws_role       = "CIDeployAccess"
}

provider "aws" {
  region = local.workspace.aws_region
  assume_role {
    role_arn = "arn:aws:iam::${local.workspace.aws_account_id}:role/${local.aws_role}"
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::${local.workspace.aws_account_id}:role/${local.aws_role}"
  }
}
