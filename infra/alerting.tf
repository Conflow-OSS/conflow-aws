module "alerting" {
  source = "../modules/alerting"

  name = "${var.name}-redis-health"

  alarms = [
    {
      name        = "${var.name}-redis-cpu"
      namespace   = "AWS/ElastiCache"
      metric_name = "EngineCPUUtilization"
      # AWS's standard node-naming convention for a replication group's
      # sole node, given num_cache_clusters = 1 — revisit this dimension
      # if that ever changes.
      dimensions          = { CacheClusterId = "${var.name}-001" }
      threshold           = 75
      comparison_operator = "GreaterThanThreshold"
    },
    {
      name                = "${var.name}-redis-memory"
      namespace           = "AWS/ElastiCache"
      metric_name         = "DatabaseMemoryUsagePercentage"
      dimensions          = { CacheClusterId = "${var.name}-001" }
      threshold           = 80
      comparison_operator = "GreaterThanThreshold"
    },
  ]

  slack_channel_id = var.slack_channel_id
  slack_team_id    = var.slack_team_id
}
