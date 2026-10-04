module "queue_depth_lambda" {
  source = "../modules/queue-depth-lambda"

  name       = "${var.name}-queue-depth"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  redis_host = module.redis.primary_endpoint
  redis_port = module.redis.port
  queue_name = var.queue_name
}
