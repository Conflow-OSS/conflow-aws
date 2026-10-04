# One cluster per environment, shared by all three services (BFF, API,
# worker) via modules/ecs-service — not one cluster per service. See
# IaC.md's Toolchain/Module layout section.
resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }
}

# Associates both capacity providers with the cluster so individual
# services can pick FARGATE vs FARGATE_SPOT via their own
# capacity_provider_strategy (modules/ecs-service always sets one
# explicitly) — no cluster-level default strategy needed.
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}
