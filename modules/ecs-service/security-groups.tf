resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Task security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = var.name }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_allowed" {
  for_each = toset(var.ingress_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value
  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
