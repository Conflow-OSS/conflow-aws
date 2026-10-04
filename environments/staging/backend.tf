# Bucket/table come from running bootstrap/bootstrap.sh once — see
# prerequisites.md. Same bucket and table as environments/production, only
# the key differs.
terraform {
  backend "s3" {
    bucket         = "REPLACE_WITH_BOOTSTRAP_BUCKET_NAME"
    key            = "staging/terraform.tfstate"
    region         = "REPLACE_WITH_BOOTSTRAP_REGION"
    dynamodb_table = "REPLACE_WITH_BOOTSTRAP_TABLE_NAME"
    encrypt        = true
  }
}
