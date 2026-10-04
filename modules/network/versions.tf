# Deliberately no `version` constraint here — this is a reusable module,
# not a root module. The exact AWS provider version is pinned exactly once,
# in each environment's root versions.tf, and propagates down to every
# module through normal provider inheritance. See IaC.md's Toolchain
# section.
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
