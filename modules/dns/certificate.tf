resource "aws_acm_certificate" "this" {
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# One CNAME per domain_validation_options entry (normally just one, for a
# single domain_name with no SANs). Deliberately unproxied — this is a
# one-time DNS challenge response ACM needs to see directly, not traffic
# Cloudflare should sit in front of.
resource "cloudflare_dns_record" "validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => dvo
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.resource_record_name, ".")
  type    = each.value.resource_record_type
  content = trimsuffix(each.value.resource_record_value, ".")
  ttl     = var.validation_record_ttl
  proxied = false
}

# Blocks on the validation record(s) actually propagating and ACM seeing
# them — downstream consumers of this module's certificate_arn output only
# ever get a cert that has already reached ISSUED.
resource "aws_acm_certificate_validation" "this" {
  provider = aws.us_east_1

  certificate_arn = aws_acm_certificate.this.arn
  validation_record_fqdns = [
    for dvo in aws_acm_certificate.this.domain_validation_options : trimsuffix(dvo.resource_record_name, ".")
  ]

  depends_on = [cloudflare_dns_record.validation]
}
