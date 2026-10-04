variable "name" {
  description = "Prefix used for the VPC and its sub-resources' Name tags, e.g. \"conflow-staging\"."
  type        = string
}

variable "cidr" {
  description = "CIDR block for the VPC, e.g. \"10.0.0.0/16\"."
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to spread public/private subnets across."
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = <<-EOT
    Use one NAT Gateway for all private subnets instead of one per AZ.
    Cost-optimized, accepted single-AZ-dependency trade-off for both
    environments — see aws-architecture.md's "Pending decisions".
  EOT
  type        = bool
  default     = true
}
