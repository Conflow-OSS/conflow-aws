variable "name" {
  type = string
}

variable "domain_name" {
  description = "Custom domain this distribution answers to, e.g. \"staging.conflow.app\" — set as the distribution's one alias."
  type        = string
}

variable "certificate_arn" {
  description = "Validated ACM cert ARN from modules/dns, covering domain_name."
  type        = string
}

variable "alb_dns_name" {
  description = "The BFF's ALB DNS name — the default behavior's origin. HTTP-only; see IaC.md's DNS & TLS section for why that's fine."
  type        = string
}

variable "bucket_regional_domain_name" {
  description = "The cards bucket's regional domain name — the /cards/* behavior's origin, reached via Origin Access Control."
  type        = string
}

variable "cards_path_pattern" {
  type    = string
  default = "/cards/*"
}

variable "waf_rate_limit" {
  type    = number
  default = 2000
}
