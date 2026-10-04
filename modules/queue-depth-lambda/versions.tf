# No version constraint on aws here deliberately — see
# modules/network/versions.tf and IaC.md's Toolchain section. The exact
# pin lives only in each environment's root versions.tf. The archive
# provider (zips the Lambda source) isn't a real AWS-facing provider, so
# it's pinned inline here rather than at the root — nothing above this
# module needs to know it exists.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "= 2.8.1"
    }
  }
}
