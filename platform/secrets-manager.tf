resource "aws_secretsmanager_secret" "secrets_manager" {
  for_each = { for secrets in try(local.workspace.secrets_manager.secrets, []) : secrets.name => secrets }
  name     = each.value.name
}