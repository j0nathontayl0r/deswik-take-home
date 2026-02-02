variable "domain_names" {
  description = "Domain names for this certificate - the first is the main domain and others are subject alternative names"
}

variable "validation_method" {
  description = "DNS, EMAIL or NONE"
  default     = "DNS"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone to create validation records. For use when validation_method is DNS. Leave it blank to validate manually."
  default     = ""
}