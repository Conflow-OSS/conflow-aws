variable "name" {
  description = "Prefix for almost everything this stack creates, e.g. \"conflow-staging\"."
  type        = string
}

# --- Networking ---------------------------------------------------------

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

# --- DNS / TLS -----------------------------------------------------------

variable "domain_name" {
  description = "FQDN this environment answers to, e.g. \"staging.conflow.app\"."
  type        = string
}

variable "cloudflare_zone_id" {
  type = string
}

# --- Container images ------------------------------------------------------

variable "server_image" {
  description = "Shared by the API and worker — same image, different command. e.g. \"ghcr.io/conflow-oss/conflow/server:1\"."
  type        = string
}

variable "webserver_image" {
  description = "The BFF's own image, e.g. \"ghcr.io/conflow-oss/conflow/webserver:1\"."
  type        = string
}

# --- Ports -----------------------------------------------------------------
# Match packages/web/.env's PORT and packages/server/.env's API_PORT exactly
# — not the (stale) defaults in either package's .env.example.

variable "bff_container_port" {
  type    = number
  default = 4000
}

variable "api_container_port" {
  type    = number
  default = 5000
}

# --- BFF sizing --------------------------------------------------------

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

# --- API sizing --------------------------------------------------------

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

# --- Worker sizing -------------------------------------------------------

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

# --- Aurora ----------------------------------------------------------------

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

# --- Redis -------------------------------------------------------------

variable "redis_node_type" {
  type    = string
  default = "cache.t4g.small"
}

# --- Edge --------------------------------------------------------------

variable "waf_rate_limit" {
  type    = number
  default = 2000
}

# --- Alerting ----------------------------------------------------------

variable "slack_channel_id" {
  type = string
}

variable "slack_team_id" {
  type = string
}

# --- Queue -------------------------------------------------------------

variable "queue_name" {
  description = "BullMQ queue name — must match the app's QUEUE_NAME."
  type        = string
  default     = "content-jobs"
}

# --- Non-secret app config --------------------------------------------

variable "app_environment" {
  description = "Extra plain (non-secret) env vars merged into the API's and worker's containers — MODEL_CHANNEL, MODEL_ID, VERTEX_PROJECT, VERTEX_LOCATION, LLM_TIMEOUT_MS, and similar. See IaC.md's Secrets & IAM section for why these stay plain."
  type        = map(string)
  default     = {}
}

# --- Secrets (write-only — see IaC.md's Secrets & IAM section) ---------

variable "api_token" {
  description = "The BFF->API bearer token. Written straight into Secrets Manager via a write-only argument — never stored in state."
  type        = string
  ephemeral   = true
  sensitive   = true
}

variable "api_token_version" {
  description = "Bump to rotate api_token — OpenTofu has nothing stored to diff against, so this is what actually signals a change."
  type        = number
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
  description = "Raw GCP service account key JSON content. The app is responsible for turning this into real Google ADC at startup (e.g. writing it to a file and setting GOOGLE_APPLICATION_CREDENTIALS) — that's an app-side concern, not this repo's. See IaC.md's Vertex AI note on the WIF alternative, not built yet."
  type        = string
  ephemeral   = true
  sensitive   = true
}

variable "external_credentials_version" {
  description = "Bump to rotate any of voyage_api_key/imejis_api_key/vertex_service_account_key."
  type        = number
}
