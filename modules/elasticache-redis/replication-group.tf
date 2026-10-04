resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "Conflow BullMQ queue (${var.name})"

  engine         = "valkey"
  engine_version = var.engine_version
  node_type      = var.node_type

  num_cache_clusters         = var.num_cache_clusters
  automatic_failover_enabled = var.automatic_failover_enabled

  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.this.id]
  parameter_group_name = aws_elasticache_parameter_group.this.name

  at_rest_encryption_enabled = true

  # ioredis (what the app uses) accepts a rediss:// URL directly with no
  # code change in the common case — infra/'s REDIS_URL is built with that
  # scheme. "required" (not "preferred") is safe to set at creation time
  # for a brand-new replication group — the preferred-then-required
  # two-step is only needed when migrating an *existing*, already-running
  # cluster from unencrypted to encrypted without downtime.
  transit_encryption_enabled = true
  transit_encryption_mode    = "required"
}
