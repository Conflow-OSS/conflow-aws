data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

module "alb" {
  source = "../modules/alb"

  name     = local.bff_name
  internal = false

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.public_subnet_ids

  allowed_prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]

  target_groups = [
    {
      key  = "bff"
      port = var.bff_container_port
      health_check = {
        path = "/"
      }
    }
  ]

  listeners = [
    {
      port                     = 80
      protocol                 = "HTTP"
      default_target_group_key = "bff"
    }
  ]
}
