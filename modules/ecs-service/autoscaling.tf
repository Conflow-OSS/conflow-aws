resource "aws_appautoscaling_target" "this" {
  min_capacity       = var.min_count
  max_capacity       = var.max_count
  resource_id        = "service/${var.cluster_name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "this" {
  for_each = { for idx, m in var.autoscaling_metrics : "${m.type}-${idx}" => m }

  name               = "${var.name}-${each.key}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = each.value.target_value

    dynamic "predefined_metric_specification" {
      for_each = each.value.type == "cpu" ? [1] : []
      content {
        predefined_metric_type = "ECSServiceAverageCPUUtilization"
      }
    }

    dynamic "predefined_metric_specification" {
      for_each = each.value.type == "alb_request_count" ? [1] : []
      content {
        predefined_metric_type = "ALBRequestCountPerTarget"
        resource_label         = each.value.resource_label
      }
    }

    dynamic "customized_metric_specification" {
      for_each = each.value.type == "custom_cloudwatch" ? [1] : []
      content {
        metric_name = each.value.customized_metric.metric_name
        namespace   = each.value.customized_metric.namespace
        statistic   = each.value.customized_metric.statistic

        dynamic "dimensions" {
          for_each = each.value.customized_metric.dimensions
          content {
            name  = dimensions.key
            value = dimensions.value
          }
        }
      }
    }
  }
}
