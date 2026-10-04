output "app_url" {
  value = module.infra.app_url
}

output "alb_dns_name" {
  value = module.infra.alb_dns_name
}

output "distribution_domain_name" {
  value = module.infra.distribution_domain_name
}

output "aurora_cluster_endpoint" {
  value = module.infra.aurora_cluster_endpoint
}

output "redis_primary_endpoint" {
  value = module.infra.redis_primary_endpoint
}

output "cards_bucket_name" {
  value = module.infra.cards_bucket_name
}
