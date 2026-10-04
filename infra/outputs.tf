output "alb_dns_name" {
  value = module.alb.dns_name
}

output "distribution_domain_name" {
  value = module.cdn.distribution_domain_name
}

output "app_url" {
  value = "https://${var.domain_name}"
}

output "aurora_cluster_endpoint" {
  value = module.aurora.cluster_endpoint
}

output "redis_primary_endpoint" {
  value = module.redis.primary_endpoint
}

output "cards_bucket_name" {
  value = local.cards_bucket_name
}
