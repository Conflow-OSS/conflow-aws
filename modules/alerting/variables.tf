variable "name" {
  type = string
}

variable "alarms" {
  description = "One entry per CloudWatch alarm, all routed to the same SNS topic / Slack channel. Used today for ElastiCache CPU/memory; reusable later for Aurora or ALB alarms without new module code."
  type = list(object({
    name                = string
    namespace           = string
    metric_name         = string
    dimensions          = optional(map(string), {})
    threshold           = number
    comparison_operator = string
    statistic           = optional(string, "Average")
    evaluation_periods  = optional(number, 3)
    period              = optional(number, 60)
  }))
}

variable "slack_channel_id" {
  type = string
}

variable "slack_team_id" {
  description = "Slack workspace ID authorized with AWS Chatbot."
  type        = string
}
