module "ecs_service_api" {
  source = "../modules/ecs-service"

  name         = local.api_name
  cluster_name = module.ecs_cluster.cluster_name
  vpc_id       = module.network.vpc_id
  subnet_ids   = module.network.private_subnet_ids

  image          = var.server_image
  command        = local.api_command
  container_port = var.api_container_port
  cpu            = var.api_cpu
  memory         = var.api_memory

  min_count = var.api_min_count
  max_count = var.api_max_count

  # Server (not client-only): exposed to the BFF under its own name.
  service_connect = {
    namespace_arn = aws_service_discovery_http_namespace.this.arn
    port_name     = "api"
  }

  ingress_security_group_ids = [module.ecs_service_bff.security_group_id]

  autoscaling_metrics = [
    { type = "cpu", target_value = 60 },
    {
      type         = "custom_cloudwatch"
      target_value = 1000
      customized_metric = {
        metric_name = "RequestCount"
        namespace   = "AWS/ECS"
        statistic   = "Sum"
        dimensions = {
          DiscoveryName = local.api_name
          ServiceName   = local.api_name
          ClusterName   = module.ecs_cluster.cluster_name
        }
      }
    },
  ]

  secrets = {
    # The API validates incoming requests against this — must match the
    # BFF's copy exactly.
    API_TOKEN = aws_secretsmanager_secret.api_token.arn

    # Aurora's AWS-managed password — Terraform never sees the value, only
    # this ARN. Consumed by local.entrypoint_prelude to assemble
    # DATABASE_URL at container start.
    DB_PASSWORD = "${module.aurora.master_user_secret_arn}:password::"

    VOYAGE_API_KEY             = "${aws_secretsmanager_secret.external_api_credentials.arn}:VOYAGE_API_KEY::"
    IMEJIS_API_KEY             = "${aws_secretsmanager_secret.external_api_credentials.arn}:IMEJIS_API_KEY::"
    VERTEX_SERVICE_ACCOUNT_KEY = "${aws_secretsmanager_secret.external_api_credentials.arn}:VERTEX_SERVICE_ACCOUNT_KEY::"
  }

  environment = merge(var.app_environment, {
    API_PORT = tostring(var.api_container_port)
    # NOT the .env.example's 127.0.0.1 default — that would make the API
    # unreachable from the Service Connect proxy inside its own task.
    API_HOST = "0.0.0.0"

    DB_HOST = module.aurora.cluster_endpoint
    DB_PORT = tostring(module.aurora.port)
    DB_NAME = module.aurora.database_name
    DB_USER = "conflow"

    # rediss:// (not redis://) — ElastiCache's transit encryption is on;
    # ioredis enables TLS automatically from this scheme alone.
    REDIS_URL = "rediss://${module.redis.primary_endpoint}:${module.redis.port}"

    # Assumes MinioImageStore's pending fix (optional credentials/endpoint,
    # urlFor() not doubling the bucket name into the path) — see IaC.md's
    # App integration notes.
    IMAGE_STORE         = "minio"
    S3_BUCKET           = local.cards_bucket_name
    S3_PUBLIC_URL_BASE  = "https://${var.domain_name}/cards"
    S3_FORCE_PATH_STYLE = "false"
    S3_PUBLIC_READ      = "false" # the bucket is private behind CloudFront OAC — a public policy attempt would just fail
  })

  task_role_policy_json = data.aws_iam_policy_document.cards_bucket_access.json
}
