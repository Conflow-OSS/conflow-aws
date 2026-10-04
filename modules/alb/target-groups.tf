resource "aws_lb_target_group" "this" {
  for_each = { for tg in var.target_groups : tg.key => tg }

  # name_prefix caps at 6 chars; the full key still lives in the Name tag
  # for readability.
  name_prefix = substr(each.value.key, 0, 6)
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = "ip" # required for Fargate awsvpc networking

  health_check {
    path                = each.value.health_check.path
    matcher             = each.value.health_check.matcher
    interval            = each.value.health_check.interval
    timeout             = each.value.health_check.timeout
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
  }

  tags = { Name = "${var.name}-${each.value.key}" }

  lifecycle {
    create_before_destroy = true
  }
}
