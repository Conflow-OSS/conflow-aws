module "dns" {
  source = "../modules/dns"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name        = var.domain_name
  cloudflare_zone_id = var.cloudflare_zone_id
}
