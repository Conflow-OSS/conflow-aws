resource "aws_lb_listener" "this" {
  for_each = { for l in var.listeners : tostring(l.port) => l }

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.protocol == "HTTPS" ? each.value.certificate_arn : null
  ssl_policy        = each.value.protocol == "HTTPS" ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.default_target_group_key].arn
  }
}
