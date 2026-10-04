locals {
  # Service Connect needs a named port mapping to reference — harmless to
  # always set one, even for services that don't use Service Connect.
  port_name = try(var.service_connect.port_name, var.name)
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.this.arn
  task_role_arn            = aws_iam_role.this.arn

  container_definitions = jsonencode([
    merge(
      {
        name  = var.name
        image = var.image

        portMappings = [
          {
            name          = local.port_name
            containerPort = var.container_port
            protocol      = "tcp"
            appProtocol   = var.app_protocol
          }
        ]

        environment = [for k, v in var.environment : { name = k, value = v }]
        secrets     = [for k, arn in var.secrets : { name = k, valueFrom = arn }]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = aws_cloudwatch_log_group.this.name
            "awslogs-region"        = data.aws_region.current.region
            "awslogs-stream-prefix" = var.name
          }
        }
      },
      # Only present in the JSON at all when set — an explicit `null`
      # command in a container definition is not the same as omitting it.
      var.command != null ? { command = var.command } : {}
    )
  ])
}
