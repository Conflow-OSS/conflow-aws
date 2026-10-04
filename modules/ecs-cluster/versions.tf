# No version constraint here deliberately — see modules/network/versions.tf
# and IaC.md's Toolchain section. The exact pin lives only in each
# environment's root versions.tf.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
