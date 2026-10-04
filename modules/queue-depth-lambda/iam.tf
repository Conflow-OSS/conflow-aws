data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = "${var.name}-"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Covers log group write access AND the ENI create/describe/delete
# permissions this Lambda needs just for running inside the VPC at all
# (Redis is private) — both come from this one AWS-managed policy.
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "put_metric_data" {
  statement {
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"] # PutMetricData doesn't support resource-level permissions
  }
}

resource "aws_iam_role_policy" "put_metric_data" {
  name   = "${var.name}-put-metric-data"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.put_metric_data.json
}
