# No version constraint here deliberately — see modules/network/versions.tf
# and IaC.md's Toolchain section. The exact pin lives only in each
# environment's root versions.tf.
#
# `configuration_aliases` on aws is required here: CloudFront-scoped ACM
# certificates must be requested in us-east-1 regardless of the stack's
# main region, so this module needs its caller to pass a us-east-1-aliased
# aws provider explicitly via `providers = { aws.us_east_1 = aws.us_east_1 }`
# — every layer above this (infra -> environments/*) has to pass it through
# too. See IaC.md's DNS & TLS section.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}
