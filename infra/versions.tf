# No version constraint here deliberately — see modules/network/versions.tf
# and IaC.md's Toolchain section. The exact pin lives only in each
# environment's root versions.tf.
#
# configuration_aliases on aws: passed through to modules/dns and
# modules/cdn (which passes it on to modules/waf) — every layer in this
# chain needs it declared. cloudflare: used directly below for the final
# public CNAME, and passed through to modules/dns.
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
