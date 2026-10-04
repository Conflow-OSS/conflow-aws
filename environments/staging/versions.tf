# The single source of truth for every pinned version in this stack — see
# IaC.md's Toolchain section. environments/production's versions.tf must
# stay byte-for-byte identical to this one.
terraform {
  required_version = "= 1.13.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.67.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "= 5.27.0"
    }
  }
}
