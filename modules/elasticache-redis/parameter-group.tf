# BullMQ requires noeviction — losing a queued job to memory-pressure
# eviction is a correctness bug for a job queue, not a performance one.
# "valkey8" is the correct parameter group family for Valkey 8.0/8.1/8.2
# (confirmed against AWS's engine-specific-parameters docs) — not an
# ElastiCache default, has to be set explicitly.
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name}-noeviction"
  family = "valkey8"

  parameter {
    name  = "maxmemory-policy"
    value = "noeviction"
  }
}
