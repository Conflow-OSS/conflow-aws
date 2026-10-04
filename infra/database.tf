module "aurora" {
  source = "../modules/aurora-postgres"

  name       = var.name
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids

  allowed_security_group_ids = [
    module.ecs_service_api.security_group_id,
    module.ecs_service_worker.security_group_id,
  ]

  min_capacity        = var.aurora_min_capacity
  max_capacity        = var.aurora_max_capacity
  deletion_protection = var.aurora_deletion_protection
  skip_final_snapshot = var.aurora_skip_final_snapshot
}
