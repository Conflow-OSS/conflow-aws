resource "aws_ecs_service" "this" {
  name            = var.name
  cluster         = var.cluster_name
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.min_count

  capacity_provider_strategy {
    capacity_provider = var.capacity_provider
    weight            = 1
    base              = 0
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = var.load_balancer != null ? [var.load_balancer] : []
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = var.name
      container_port   = load_balancer.value.container_port
    }
  }

  health_check_grace_period_seconds = var.load_balancer != null ? var.health_check_grace_period_seconds : null

  dynamic "service_connect_configuration" {
    for_each = var.service_connect != null ? [var.service_connect] : []
    content {
      enabled   = true
      namespace = service_connect_configuration.value.namespace_arn

      # Omitted entirely for a client-only participant (BFF: joins the
      # namespace just to resolve the API's name, exposes nothing of its
      # own). Present only when port_name is set (the API).
      dynamic "service" {
        for_each = service_connect_configuration.value.port_name != null ? [service_connect_configuration.value] : []
        content {
          port_name      = service.value.port_name
          discovery_name = coalesce(service.value.discovery_name, var.name)

          client_alias {
            port     = var.container_port
            dns_name = coalesce(service.value.discovery_name, var.name)
          }
        }
      }
    }
  }

  # Application Auto Scaling owns desired_count once aws_appautoscaling_target
  # exists — without this, every `tofu apply` would fight it back to
  # min_count.
  lifecycle {
    ignore_changes = [desired_count]
  }
}
