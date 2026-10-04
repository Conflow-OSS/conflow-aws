# No inbound rules — this Lambda only ever initiates connections (to
# Redis, to CloudWatch). Its id is exported so the caller can add it to
# modules/elasticache-redis's allowed_security_group_ids list.
resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "Queue-depth Lambda for ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = var.name }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
