# terraform-aws-acm-certificate

<!--- BEGIN_TF_DOCS --->

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 0.13.0 |
| aws | >= 2.7.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 2.7.0 |

<!-- markdownlint-disable MD013 -->

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| domain\_names | Domain names for this certificate - the first is the main domain and others are subject alternative names | `any` | n/a | yes |
| hosted\_zone\_id | Route53 hosted zone to create validation records. For use when validation\_method is DNS. Leave it blank to validate manually. | `string` | `""` | no |
| validation\_method | DNS, EMAIL or NONE | `string` | `"DNS"` | no |

## Outputs

| Name | Description |
|------|-------------|
| arn | n/a |
| dns\_validation\_records | n/a |
| id | n/a |

<!--- END_TF_DOCS --->
