resource "local_file" "outputs" {
  content = jsonencode({
    "domain" : { for domain, zone in aws_route53_zone.default : domain => zone }
    "acm_certificate" : element(module.acm_certificate[*], 0)
    "network" : try(module.network[0], {})
  })
  filename = "${path.module}/.clients/client-${local.client}/.outputs/${local.stack_name}-${terraform.workspace}.json"
}
