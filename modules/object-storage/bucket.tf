# Private — reachable only via CloudFront's Origin Access Control, wired up
# as a standalone aws_s3_bucket_policy resource in infra/ (not here) to
# avoid this module and modules/cdn depending on each other. See IaC.md's
# "CDN/S3/DNS wiring" note.
resource "aws_s3_bucket" "this" {
  bucket = var.name
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}
