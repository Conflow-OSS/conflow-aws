# Staging: cost-reduced — min 1 task per service, no HA requirement.
# Compare against environments/production/terraform.tfvars, which keeps
# the min-2/multi-AZ shape. Same module code either way.

name     = "conflow-staging"
vpc_cidr = "10.0.0.0/16"

domain_name        = "staging.conflow.onukwilip.me" # REPLACE with the real staging subdomain
cloudflare_zone_id = "REPLACE_WITH_CLOUDFLARE_ZONE_ID"

server_image    = "ghcr.io/conflow-oss/conflow/server:1"    # REPLACE with the tag actually being deployed
webserver_image = "ghcr.io/conflow-oss/conflow/webserver:1" # REPLACE with the tag actually being deployed

bff_min_count = 1
bff_max_count = 2

api_min_count = 1
api_max_count = 2

worker_min_count = 1
worker_max_count = 2

# infra/'s defaults (true/false) are production-oriented — staging gets
# iterated/torn down more often, so these are flipped for easy
# destroy/recreate instead of blocking on deletion_protection.
aurora_deletion_protection = false
aurora_skip_final_snapshot = true

slack_channel_id = "REPLACE_WITH_SLACK_CHANNEL_ID"
slack_team_id    = "REPLACE_WITH_SLACK_WORKSPACE_ID"

# Non-secret app config — see packages/server/.env.example for the full
# list this can carry (MODEL_CHANNEL, VERTEX_PROJECT, VERTEX_LOCATION,
# EMBED_MODEL, DEDUP_*, LLM_*, WORKER_CONCURRENCY, and so on).
app_environment = {
  MODEL_CHANNEL   = "vertex"
  VERTEX_PROJECT  = "REPLACE_WITH_GCP_PROJECT_ID"
  VERTEX_LOCATION = "global"
}
