resource "aws_security_group" "this" {
  name_prefix = "${var.name}-"
  description = "ALB security group for ${var.name}"
  vpc_id      = var.vpc_id

  tags = { Name = "${var.name}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

locals {
  # One ingress rule per (listener port, prefix list) pair and per
  # (listener port, cidr block) pair — flattened so a single for_each can
  # create them all without nested resource blocks.
  prefix_list_ingress = flatten([
    for l in var.listeners : [
      for pl in var.allowed_prefix_list_ids : {
        key    = "${l.port}-pl-${pl}"
        port   = l.port
        prefix = pl
      }
    ]
  ])

  cidr_ingress = flatten([
    for l in var.listeners : [
      for cidr in var.allowed_cidr_blocks : {
        key  = "${l.port}-cidr-${cidr}"
        port = l.port
        cidr = cidr
      }
    ]
  ])
}

resource "aws_vpc_security_group_ingress_rule" "from_prefix_lists" {
  for_each = { for p in local.prefix_list_ingress : p.key => p }

  security_group_id = aws_security_group.this.id
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
  prefix_list_id    = each.value.prefix
}

resource "aws_vpc_security_group_ingress_rule" "from_cidr_blocks" {
  for_each = { for c in local.cidr_ingress : c.key => c }

  security_group_id = aws_security_group.this.id
  from_port         = each.value.port
  to_port           = each.value.port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value.cidr
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
