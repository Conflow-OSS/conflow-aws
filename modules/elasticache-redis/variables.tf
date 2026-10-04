variable "name" {
  description = "Replication group id, e.g. \"conflow-staging\"."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach Redis/Valkey on 6379 (the API's and worker's task SGs)."
  type        = list(string)
}

variable "node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "automatic_failover_enabled" {
  description = "Deferred for now (no read replica yet) — see aws-architecture.md's pending decisions. A tfvars change, not a module change, whenever that's revisited."
  type        = bool
  default     = false
}

variable "num_cache_clusters" {
  description = "1 = no read replica, matching automatic_failover_enabled = false."
  type        = number
  default     = 1
}

variable "engine_version" {
  description = "Valkey engine version. 8.2 confirmed current and GA as of this module's implementation — AWS's drop-in, Redis-OSS-protocol-compatible successor, recommended for all new ElastiCache deployments (cheaper than licensed Redis OSS, and Redis OSS on ElastiCache is capped at 7.1 going forward). BullMQ/ioredis talk wire protocol only, so this is a transparent swap. See IaC.md's Redis section."
  type        = string
  default     = "8.2"
}
