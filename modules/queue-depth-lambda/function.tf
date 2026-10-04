resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.this.arn

  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  handler = "index.handler"
  runtime = "nodejs22.x"
  timeout = 15

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  environment {
    variables = {
      QUEUE_NAME       = var.queue_name
      REDIS_HOST       = var.redis_host
      REDIS_PORT       = tostring(var.redis_port)
      METRIC_NAMESPACE = var.metric_namespace
      METRIC_NAME      = var.metric_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]
}
