data "aws_kms_key" "s3" {
  key_id = "alias/cmk/s3"
}

resource "aws_s3_bucket" "bucket" {
  for_each      = { for bucket in try(local.workspace.buckets, []) : bucket.name => bucket }
  bucket_prefix = "${local.workspace.account_name}-${each.value.name}"
}

resource "aws_s3_bucket" "import_bucket" {
  for_each = { for bucket in try(local.workspace.import_buckets, []) : bucket.name => bucket }
  bucket   = each.value.name
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bucket" {
  for_each = { for bucket in try(local.workspace.buckets, []) : bucket.name => bucket }
  bucket   = aws_s3_bucket.bucket[each.value.name].bucket

  rule {
    bucket_key_enabled = (try(each.value.kms_key_arn, null) != null) || (!try(each.value.default_cmk, false))
    apply_server_side_encryption_by_default {
      kms_master_key_id = try(each.value.default_cmk, false) ? data.aws_kms_key.s3.arn : try(each.value.kms_key_arn, "")
      sse_algorithm     = try(each.value.kms_key_arn, null) == null ? "AES256" : "aws:kms"
    }
  }
}

resource "aws_s3_bucket_policy" "aws_s3_bucket_policy" {
  for_each = { for bucket in try(local.workspace.buckets, []) : bucket.name => bucket
    if length(try(bucket.statement, [])) > 0
  }
  bucket = aws_s3_bucket.bucket[each.value.name].id
  policy = data.aws_iam_policy_document.aws_s3_bucket_policy[each.value.name].json

  lifecycle {
    ignore_changes = [policy]
  }
}

data "aws_iam_policy_document" "aws_s3_bucket_policy" {
  for_each = { for bucket in try(local.workspace.buckets, []) : bucket.name => bucket
    if length(try(bucket.statement, [])) > 0
  }

  dynamic "statement" {
    for_each = try(each.value.statement, [])
    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = concat(try(statement.value.resources, []), ["${aws_s3_bucket.bucket[each.value.name].arn}", "${aws_s3_bucket.bucket[each.value.name].arn}/*"])

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.condition, [])
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }

      }
    }
  }

  dynamic "statement" {
    for_each = try(each.value.access_from.ecs, [])

    content {
      sid       = "EcsClusterFullAccess"
      actions   = ["s3:*"]
      resources = ["${aws_s3_bucket.bucket[each.value.name].arn}", "${aws_s3_bucket.bucket[each.value.name].arn}/*"]

      principals {
        type        = "AWS"
        identifiers = [module.ecs_cluster[statement.value.cluster_name].ecs_task_iam_role_arn]
      }
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "bucket" {
  for_each = { for bucket in try(local.workspace.buckets, []) : bucket.name => bucket
    if length(try(bucket.cors_rule, [])) > 0
  }
  bucket = aws_s3_bucket.bucket[each.value.name].bucket

  dynamic "cors_rule" {
    for_each = try(each.value.cors_rule, [])
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = try(cors_rule.value.max_age_seconds, null)
    }
  }
}