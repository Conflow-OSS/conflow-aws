# No version constraint here deliberately — see modules/network/versions.tf
# and IaC.md's Toolchain section. The exact pin lives only in each
# environment's root versions.tf.
#
# `configuration_aliases` is required: a CloudFront-scoped (scope =
# "CLOUDFRONT") Web ACL must be created in us-east-1 regardless of the
# stack's main region, so this module needs its caller to pass a
# us-east-1-aliased aws provider via `providers = { aws.us_east_1 =
# aws.us_east_1 }` — every layer above this (modules/cdn -> infra ->
# environments/*) has to pass it through too. See IaC.md's Edge section.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
