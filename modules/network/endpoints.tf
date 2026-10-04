# The S3 Gateway VPC Endpoint — a free, route-table-level association (not a
# security group concern) that keeps API/worker <-> S3 traffic off the NAT
# Gateway entirely. See IaC.md's Networking section.
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "6.7.3" # must match module.vpc's version in vpc.tf

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
    }
  }
}
