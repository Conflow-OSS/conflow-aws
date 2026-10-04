provider "aws" {
  region = "us-east-1" # REPLACE if the stack's main region differs
}

# CloudFront-scoped ACM certs and WAF Web ACLs must be created in
# us-east-1 regardless of the main region above — passed down through
# infra -> modules/cdn -> modules/waf and infra -> modules/dns. See
# IaC.md's DNS & TLS and Edge sections.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# Auth via CLOUDFLARE_API_TOKEN env var — see prerequisites.md. Never set
# here.
provider "cloudflare" {}
