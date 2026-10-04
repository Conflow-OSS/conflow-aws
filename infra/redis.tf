module "redis" {
  source = "../modules/elasticache-redis"

  name       = var.name
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  allowed_security_group_ids = [
    module.ecs_service_api.security_group_id,
    module.ecs_service_worker.security_group_id,
    module.queue_depth_lambda.security_group_id,
  ]

  node_type = var.redis_node_type
}
