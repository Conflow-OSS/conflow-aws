data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # /24s carved out of the VPC CIDR: az_count private subnets, then az_count
  # public ones. Plain and readable for a small, fixed subnet count — not
  # worth a more general cidrsubnets() scheme for just two tiers.
  private_subnets = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i)]
  public_subnets  = [for i in range(var.az_count) : cidrsubnet(var.cidr, 8, i + var.az_count)]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  # Requires aws provider >= 6.28 (confirmed via this version's versions.tf
  # on GitHub) — keep in step with whatever exact `aws` provider version is
  # pinned in environments/*/versions.tf. Bump this and
  # module.vpc_endpoints's version in endpoints.tf together; they must
  # always match.
  version = "6.7.3"

  name = var.name
  cidr = var.cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  enable_nat_gateway     = true
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true
}
