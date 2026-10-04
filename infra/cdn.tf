module "cdn" {
  source = "../modules/cdn"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name            = var.name
  domain_name     = var.domain_name
  certificate_arn = module.dns.certificate_arn
  alb_dns_name    = module.alb.dns_name

  bucket_regional_domain_name = module.cards_bucket.bucket_regional_domain_name

  waf_rate_limit = var.waf_rate_limit
}

# The final public record — only created once the distribution exists,
# pointing domain_name at it. Deliberately a standalone resource here, not
# inside modules/dns or modules/cdn, so neither has to depend on the other
# (modules/dns only ever produces a certificate; it never learns the
# CloudFront domain name). Unproxied: Cloudflare is pure DNS, CloudFront
# does all the real work. See IaC.md's DNS & TLS section.
resource "cloudflare_dns_record" "app" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  type    = "CNAME"
  content = module.cdn.distribution_domain_name
  ttl     = 300
  proxied = false
}
