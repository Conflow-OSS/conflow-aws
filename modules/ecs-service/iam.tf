# One role per service, used as BOTH the task role and the execution
# role — not two separate roles. ECS's execution role (what the agent uses
# to pull the image, write logs, and fetch var.secrets' values before the
# container starts) and the task role (what the running container's own
# AWS SDK calls use) can be the same role, since both are assumed by the
# same ecs-tasks.amazonaws.com principal. IaC.md's Secrets & IAM section
# already describes "one aws_iam_role per service" — this is that.
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name_prefix        = "${var.name}-"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Scoped to exactly the secret ARNs this service was handed, nothing
# broader — least-privilege by construction, matching IaC.md.
data "aws_iam_policy_document" "secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  statement {
    actions   = ["secretsmanager:GetSecretValue"]
    resources = distinct(values(var.secrets))
  }
}

resource "aws_iam_role_policy" "secrets" {
  count = length(var.secrets) > 0 ? 1 : 0

  name   = "${var.name}-secrets"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.secrets[0].json
}

resource "aws_iam_role_policy" "extra" {
  count = var.task_role_policy_json != null ? 1 : 0

  name   = "${var.name}-extra"
  role   = aws_iam_role.this.id
  policy = var.task_role_policy_json
}
