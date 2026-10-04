# AWS-managed cache/origin-request policies, referenced by name rather than
# hardcoding their IDs — the modern replacement for the deprecated
# forwarded_values block.
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

resource "aws_cloudfront_distribution" "this" {
  enabled    = true
  aliases    = [var.domain_name]
  web_acl_id = module.waf.web_acl_arn

  # Default behavior: the BFF's ALB. Dynamic, not cached, every header
  # forwarded — this is the path the SSE route and /api/* take, and it has
  # to stay open for the duration of a generation run. See IaC.md's Edge
  # section.
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # /cards/* behavior: the private S3 bucket, reached only via this OAC —
  # never a public bucket. Cached normally since card keys are
  # content-addressed and immutable.
  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = "cards"
    origin_access_control_id = aws_cloudfront_origin_access_control.cards.id
  }

  default_cache_behavior {
    target_origin_id       = "alb"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  ordered_cache_behavior {
    path_pattern           = var.cards_path_pattern
    target_origin_id       = "cards"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}
