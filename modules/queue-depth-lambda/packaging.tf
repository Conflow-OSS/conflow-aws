# Zips whatever's already in lambda/ — deliberately does NOT run `npm
# install` itself (no null_resource/local-exec provisioner). That's a
# documented, explicit build step instead:
#
#   cd modules/queue-depth-lambda/lambda && npm ci
#
# before the first `tofu apply`, and again whenever lambda/package.json
# changes. See prerequisites.md.
data "archive_file" "this" {
  type       = "zip"
  source_dir = "${path.module}/lambda"
  # Output lives one level up from the source dir being zipped, so the
  # zip never has to exclude itself.
  output_path = "${path.module}/dist.zip"
}
