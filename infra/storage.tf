module "cards_bucket" {
  source = "../modules/object-storage"

  name = local.cards_bucket_name
}

# The OAC bucket policy — declared here, not inside modules/cdn or
# modules/object-storage, to avoid those two modules depending on each
# other. See IaC.md's "CDN/S3/DNS wiring" note.
data "aws_iam_policy_document" "cards_bucket_policy" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${module.cards_bucket.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cdn.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cards" {
  bucket = module.cards_bucket.bucket_id
  policy = data.aws_iam_policy_document.cards_bucket_policy.json
}

# Shared by the API's and worker's roles — both render/store cards. See
# IaC.md's "S3 access keys disappear entirely" note: IAM grants replace
# S3_ACCESS_KEY/S3_SECRET_KEY entirely, no credential material to store.
data "aws_iam_policy_document" "cards_bucket_access" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.cards_bucket.bucket_arn}/*"]
  }
}
