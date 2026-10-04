# Shared by the BFF (client-only — joins just to resolve the API) and the
# API (server — exposes itself here instead of behind its own ALB).
resource "aws_service_discovery_http_namespace" "this" {
  name = var.name
}
