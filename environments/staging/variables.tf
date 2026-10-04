# Mirrors infra/variables.tf 1:1 — this is a thin root wrapper over the one
# shared infra module, so its variable surface is the same, with real
# values supplied by terraform.tfvars (sizing) and a local, gitignored
# secrets.auto.tfvars (the write-only secret values). See IaC.md's Module
# layout note and prerequisites.md.

variable "name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "az_count" {
  type    = number
  default = 2
}

variable "single_nat_gateway" {
  type    = bool
  default = true
}

variable "domain_name" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "server_image" {
  type = string
}

variable "webserver_image" {
  type = string
}

variable "bff_container_port" {
  type    = number
  default = 4000
}

variable "api_container_port" {
  type    = number
  default = 5000
}

variable "bff_min_count" {
  type = number
}

variable "bff_max_count" {
  type = number
}

variable "bff_cpu" {
  type    = number
  default = 256
}

variable "bff_memory" {
  type    = number
  default = 512
}

variable "api_min_count" {
  type = number
}

variable "api_max_count" {
  type = number
}

variable "api_cpu" {
  type    = number
  default = 256
}

variable "api_memory" {
  type    = number
  default = 512
}

variable "worker_min_count" {
  type    = number
  default = 1
}

variable "worker_max_count" {
  type = number
}

variable "worker_cpu" {
  type    = number
  default = 512
}

variable "worker_memory" {
  type    = number
  default = 1024
}

variable "aurora_min_capacity" {
  type    = number
  default = 0
}

variable "aurora_max_capacity" {
  type    = number
  default = 1
}

variable "aurora_deletion_protection" {
  type    = bool
  default = true
}

variable "aurora_skip_final_snapshot" {
  type    = bool
  default = false
}

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.small"
}

variable "waf_rate_limit" {
  type    = number
  default = 2000
}

variable "slack_channel_id" {
  type = string
}

variable "slack_team_id" {
  type = string
}

variable "queue_name" {
  type    = string
  default = "content-jobs"
}

variable "app_environment" {
  type    = map(string)
  default = {}
}

variable "api_token" {
  type      = string
  ephemeral = true
  sensitive = true
}

variable "api_token_version" {
  type = number
}

variable "voyage_api_key" {
  type      = string
  ephemeral = true
  sensitive = true
}

variable "imejis_api_key" {
  type      = string
  ephemeral = true
  sensitive = true
}

variable "vertex_service_account_key" {
  type      = string
  ephemeral = true
  sensitive = true
}

variable "external_credentials_version" {
  type = number
}
