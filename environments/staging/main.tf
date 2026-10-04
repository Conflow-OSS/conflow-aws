module "infra" {
  source = "../../infra"
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  name               = var.name
  vpc_cidr           = var.vpc_cidr
  az_count           = var.az_count
  single_nat_gateway = var.single_nat_gateway

  domain_name        = var.domain_name
  cloudflare_zone_id = var.cloudflare_zone_id

  server_image    = var.server_image
  webserver_image = var.webserver_image

  bff_container_port = var.bff_container_port
  api_container_port = var.api_container_port

  bff_min_count = var.bff_min_count
  bff_max_count = var.bff_max_count
  bff_cpu       = var.bff_cpu
  bff_memory    = var.bff_memory

  api_min_count = var.api_min_count
  api_max_count = var.api_max_count
  api_cpu       = var.api_cpu
  api_memory    = var.api_memory

  worker_min_count = var.worker_min_count
  worker_max_count = var.worker_max_count
  worker_cpu       = var.worker_cpu
  worker_memory    = var.worker_memory

  aurora_min_capacity        = var.aurora_min_capacity
  aurora_max_capacity        = var.aurora_max_capacity
  aurora_deletion_protection = var.aurora_deletion_protection
  aurora_skip_final_snapshot = var.aurora_skip_final_snapshot

  redis_node_type = var.redis_node_type

  waf_rate_limit = var.waf_rate_limit

  slack_channel_id = var.slack_channel_id
  slack_team_id    = var.slack_team_id

  queue_name = var.queue_name

  app_environment = var.app_environment

  api_token         = var.api_token
  api_token_version = var.api_token_version

  voyage_api_key             = var.voyage_api_key
  imejis_api_key             = var.imejis_api_key
  vertex_service_account_key = var.vertex_service_account_key

  external_credentials_version = var.external_credentials_version
}
