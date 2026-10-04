# No version constraint here deliberately — see modules/network/versions.tf
# and IaC.md's Toolchain section. The exact pin lives only in each
# environment's root versions.tf.
#
# aws_cloudfront_distribution itself is region-agnostic (CloudFront is a
# global service, managed through any regional provider configuration) —
# this module only needs the us-east-1 alias to pass through to the nested
# module.waf call below, not for its own resources.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}
