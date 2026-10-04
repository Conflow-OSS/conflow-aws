module "ecs_service_bff" {
  source = "../modules/ecs-service"

  name         = local.bff_name
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids

  image          = var.webserver_image
  container_port = var.bff_container_port
  cpu            = var.bff_cpu
  memory         = var.bff_memory

  min_count = var.bff_min_count
  max_count = var.bff_max_count

  load_balancer = {
    target_group_arn = module.alb.target_group_arns["bff"]
    container_port   = var.bff_container_port
  }

  # Client-only (no port_name): the BFF exposes nothing via Service
  # Connect — it only needs to join the namespace to resolve the API's
  # name. See modules/ecs-service's service_connect variable description.
  service_connect = {
    namespace_arn = aws_service_discovery_http_namespace.this.arn
  }

  ingress_security_group_ids = [module.alb.security_group_id]

  autoscaling_metrics = [
    { type = "cpu", target_value = 60 },
    {
      type           = "alb_request_count"
      target_value   = 1000
      resource_label = "${module.alb.alb_arn_suffix}/${module.alb.target_group_arn_suffixes["bff"]}"
    },
  ]

  secrets = {
    # Must match the API's own copy exactly — the API validates incoming
    # requests against the same value. See packages/web/.env.example.
    API_TOKEN = aws_secretsmanager_secret.api_token.arn
  }

  environment = {
    PORT        = tostring(var.bff_container_port)
    BACKEND_URL = "http://${module.ecs_service_api.service_name}:${var.api_container_port}"
  }
}
