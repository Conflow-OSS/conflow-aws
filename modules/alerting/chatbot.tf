data "aws_iam_policy_document" "chatbot_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "chatbot" {
  name_prefix        = "${var.name}-chatbot-"
  assume_role_policy = data.aws_iam_policy_document.chatbot_assume_role.json
}

# Lets Chatbot read alarm state to enrich the Slack message — nothing more.
resource "aws_iam_role_policy_attachment" "chatbot_read" {
  role       = aws_iam_role.chatbot.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_chatbot_slack_channel_configuration" "this" {
  configuration_name = var.name
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = var.slack_team_id
  sns_topic_arns     = [aws_sns_topic.this.arn]
  logging_level      = "ERROR"

  # AWS applies the AdministratorAccess managed policy as the guardrail by
  # DEFAULT if this is left unset (confirmed against the provider's own
  # resource docs) — this channel only ever needs to relay notifications,
  # never run chat commands, so it's locked to read-only instead of
  # silently inheriting admin-level command execution.
  guardrail_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
}
