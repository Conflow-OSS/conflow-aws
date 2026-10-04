module "ecs_cluster" {
  source = "../modules/ecs-cluster"

  name = var.name
}
