module "acm_certificate" {
  for_each = {
    for certificate in local.workspace.acm.certificates : certificate.name => certificate
    if try(certificate.global, false) == false
  }
  source = "./modules/acm_certificate"

  domain_names   = each.value.domain_names
  hosted_zone_id = can(each.value.hosted_zone) ? aws_route53_zone.default[each.value.hosted_zone].zone_id : ""
}