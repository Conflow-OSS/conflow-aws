variable "name" {
  description = "Cluster identifier, e.g. \"conflow-staging\"."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets, at least 2 AZs, for the DB subnet group."
  type        = list(string)
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to reach Postgres on 5432 (the API's and worker's task SGs)."
  type        = list(string)
}

variable "min_capacity" {
  description = <<-EOT
    Aurora Serverless v2 floor, in ACUs. 0 = true scale-to-zero. Needs
    engine_version 13.15+/14.12+/15.7+/16.3+ (confirmed via AWS's Nov 2024
    announcement) — the default engine_version below already clears that
    by a wide margin. See IaC.md's PostgreSQL section.
  EOT
  type        = number
  default     = 0
}

variable "max_capacity" {
  description = "Aurora Serverless v2 ceiling, in ACUs. Deliberately tight for now — see aws-architecture.md's pending decisions."
  type        = number
  default     = 1
}

variable "engine_version" {
  description = "Aurora PostgreSQL engine version. 18.4 confirmed as Aurora's latest supported PostgreSQL version as of 2026-08-24 — verify no newer minor exists before applying if this plan sits unused for a while."
  type        = string
  default     = "18.4"
}

variable "master_username" {
  type    = string
  default = "conflow"
}

variable "deletion_protection" {
  description = "Blocks accidental `tofu destroy`/console deletion. Should be true for production."
  type        = bool
  default     = true
}

variable "skip_final_snapshot" {
  description = "true skips the final snapshot on destroy (faster teardown — fine for staging). Should be false for production."
  type        = bool
  default     = false
}

variable "apply_immediately" {
  description = "false queues changes for the next maintenance window instead of applying them right away."
  type        = bool
  default     = false
}
