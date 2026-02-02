output "arn" {
  value = aws_acm_certificate.cert.arn
}

output "id" {
  value = aws_acm_certificate.cert.id
}

output "dns_validation_records" {
  value = aws_acm_certificate.cert.domain_validation_options
}