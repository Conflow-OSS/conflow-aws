resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = { for a in var.alarms : a.name => a }

  alarm_name          = each.value.name
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  dimensions          = each.value.dimensions
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  statistic           = each.value.statistic
  evaluation_periods  = each.value.evaluation_periods
  period              = each.value.period

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]
}
