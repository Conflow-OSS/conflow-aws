variable "domain_name" {
  description = "FQDN the certificate (and later, CloudFront's alias) will cover, e.g. \"staging.conflow.app\"."
  type        = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "validation_record_ttl" {
  description = "TTL for the DNS validation CNAME(s). Doesn't matter much for a validation-only record — 300s is a reasonable default."
  type        = number
  default     = 300
}
