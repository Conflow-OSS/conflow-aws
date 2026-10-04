variable "name" {
  description = "ALB name — AWS caps this at 32 characters, keep it short."
  type        = string
}

variable "internal" {
  description = "true for an internal (no public IP) load balancer, false for internet-facing."
  type        = bool
  default     = false
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Public subnets for an internet-facing ALB, private subnets for an internal one."
  type        = list(string)
}

variable "allowed_prefix_list_ids" {
  description = <<-EOT
    Managed prefix list IDs allowed to reach every listener port — e.g.
    CloudFront's `com.amazonaws.global.cloudfront.origin-facing` prefix
    list, via `data "aws_ec2_managed_prefix_list"`. Deliberately a prefix
    list, not a literal CIDR block — see IaC.md's Backend-for-Frontend
    section for why.
  EOT
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "Literal CIDR blocks allowed to reach every listener port, in addition to allowed_prefix_list_ids. Usually empty — only set this for an internal ALB reached from a known VPC range."
  type        = list(string)
  default     = []
}

variable "target_groups" {
  description = "One entry per target group this ALB can route to. `key` is referenced by listeners' default_target_group_key."
  type = list(object({
    key      = string
    port     = number
    protocol = optional(string, "HTTP")
    health_check = object({
      path                = string
      matcher             = optional(string, "200")
      interval            = optional(number, 30)
      timeout             = optional(number, 5)
      healthy_threshold   = optional(number, 3)
      unhealthy_threshold = optional(number, 3)
    })
  }))
}

variable "listeners" {
  description = "One entry per listener. protocol = \"HTTPS\" requires certificate_arn."
  type = list(object({
    port                     = number
    protocol                 = optional(string, "HTTP")
    certificate_arn          = optional(string)
    default_target_group_key = string
  }))

  validation {
    condition     = alltrue([for l in var.listeners : l.protocol != "HTTPS" || l.certificate_arn != null])
    error_message = "Every HTTPS listener needs a certificate_arn."
  }
}
