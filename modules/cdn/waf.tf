module "waf" {
  source = "../waf"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name       = var.name
  rate_limit = var.waf_rate_limit
}
