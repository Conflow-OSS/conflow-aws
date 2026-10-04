module "ecs_service_worker" {
  source = "../modules/ecs-service"

  name         = local.worker_name
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids

  image             = var.server_image
  command           = local.worker_command
  capacity_provider = "FARGATE_SPOT" # safe only because the job handler is idempotent/resumable — see aws-architecture.md
  # Not actually listened on (the worker runs no HTTP server) — ecs-service
  # requires some value, and this is harmless since nothing is ever
  # allowed to reach it (ingress_security_group_ids stays empty below).
  container_port = 3000
  cpu            = var.worker_cpu
  memory         = var.worker_memory

  min_count = var.worker_min_count
  max_count = var.worker_max_count

  # No load_balancer, no service_connect, no ingress — the worker only
  # ever initiates connections (Postgres, Redis, Vertex/Voyage/Imejis), it
  # never receives any.

  autoscaling_metrics = [
    {
      type         = "custom_cloudwatch"
      target_value = 5
      customized_metric = {
        metric_name = "QueueDepth"
        namespace   = "Conflow/Worker"
        statistic   = "Average"
      }
    },
  ]

  secrets = {
    DB_PASSWORD                = "${module.aurora.master_user_secret_arn}:password::"
    VOYAGE_API_KEY             = "${aws_secretsmanager_secret.external_api_credentials.arn}:VOYAGE_API_KEY::"
    IMEJIS_API_KEY             = "${aws_secretsmanager_secret.external_api_credentials.arn}:IMEJIS_API_KEY::"
    VERTEX_SERVICE_ACCOUNT_KEY = "${aws_secretsmanager_secret.external_api_credentials.arn}:VERTEX_SERVICE_ACCOUNT_KEY::"
  }

  environment = merge(var.app_environment, {
    DB_HOST = module.aurora.cluster_endpoint
    DB_PORT = tostring(module.aurora.port)
    DB_NAME = module.aurora.database_name
    DB_USER = "conflow"

    # rediss:// (not redis://) — ElastiCache's transit encryption is on;
    # ioredis enables TLS automatically from this scheme alone.
    REDIS_URL = "rediss://${module.redis.primary_endpoint}:${module.redis.port}"

    IMAGE_STORE         = "minio" # see the API's own note on this — same pending MinioImageStore fix assumed
    S3_BUCKET           = local.cards_bucket_name
    S3_PUBLIC_URL_BASE  = "https://${var.domain_name}/cards"
    S3_FORCE_PATH_STYLE = "false"
    S3_PUBLIC_READ      = "false"
  })

  task_role_policy_json = data.aws_iam_policy_document.cards_bucket_access.json
}
