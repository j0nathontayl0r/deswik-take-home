module "ecr_repository" {
  for_each             = { for repository in try(local.workspace.ecr.repositories, []) : repository.name => repository }
  source               = "./modules/aws-ecr-2.3.3"
  name                 = each.value.name
  trust_accounts       = try(local.workspace.ecr.trust_account_ids, [])
  kms_key_arn          = try(local.workspace.ecr.kms_key_arn, "")
  image_tag_mutability = try(each.value.image_tag_mutability, "MUTABLE")
  tags                 = try(each.value.tags, {})
  encryption_type      = try(local.workspace.ecr.encryption_type, "KMS")

  lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire any image after the first 30 registred, e.g., 31st, 32nd etc image is expired"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_registry_scanning_configuration" "configuration" {
  count = length(try(local.workspace.ecr.repositories, [])) > 0 ? 1 : 0

  scan_type = try(local.workspace.ecr.scan_type, "BASIC")
  rule {
    scan_frequency = try(local.workspace.ecr.scan_type, "BASIC") == "BASIC" ? "SCAN_ON_PUSH" : try(local.workspace.ecr.repositories.scan_frequency, "CONTINUOUS_SCAN")

    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
}

output "ecr_repository" {
  value = element(module.ecr_repository[*], 0)
}