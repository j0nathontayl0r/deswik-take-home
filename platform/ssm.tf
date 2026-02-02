resource "aws_ssm_parameter" "ssm_parameter_strings" {
  for_each    = try(local.workspace.ssm.strings, {})
  name        = each.key
  description = each.key
  type        = "String"
  value       = each.value
  overwrite   = try(local.workspace.ssm.overwrite, false)
  lifecycle {
    ignore_changes = [description]
  }
}

resource "aws_ssm_parameter" "ssm_parameter_secure_strings" {
  for_each    = toset(try(local.workspace.ssm.secured_strings, []))
  name        = each.key
  description = each.key
  type        = "SecureString"
  value       = "NO_VALUE"
  key_id      = try(local.workspace.ssm.kms_key_arn, "") != "" ? local.workspace.ssm.kms_key_arn : "alias/aws/ssm"
  lifecycle {
    ignore_changes = [value]
  }
}
