resource "aws_route53_zone" "default" {
  for_each = { for zone in local.workspace.domain.zones : zone.route53_domain => zone
  if local.workspace.domain.enabled }
  name = each.value.route53_domain

  dynamic "vpc" {
    for_each = each.value.private ? [true] : []
    content {
      vpc_id = module.network[0].vpc_id
    }
  }
}

output "route53_name_servers" {
  value = { for domain, zone in aws_route53_zone.default : domain => zone.name_servers }
}