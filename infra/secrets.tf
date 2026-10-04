# Two secrets, split by who needs to read them — not one shared secret.
# See IaC.md's Secrets & IAM section. Values are written via write-only
# arguments (secret_string_wo + secret_string_wo_version) so they never
# land in state or a plan diff, even though they come from local tfvars —
# see IaC.md's Secrets & IAM note for why this replaced the earlier
# out-of-band put-secret-value plan.

resource "aws_secretsmanager_secret" "api_token" {
  name = "${var.name}-api-token"
}

resource "aws_secretsmanager_secret_version" "api_token" {
  secret_id                = aws_secretsmanager_secret.api_token.id
  secret_string_wo         = var.api_token
  secret_string_wo_version = var.api_token_version
}

resource "aws_secretsmanager_secret" "external_api_credentials" {
  name = "${var.name}-external-api-credentials"
}

resource "aws_secretsmanager_secret_version" "external_api_credentials" {
  secret_id = aws_secretsmanager_secret.external_api_credentials.id
  secret_string_wo = jsonencode({
    VOYAGE_API_KEY             = var.voyage_api_key
    IMEJIS_API_KEY             = var.imejis_api_key
    VERTEX_SERVICE_ACCOUNT_KEY = var.vertex_service_account_key
  })
  secret_string_wo_version = var.external_credentials_version
}
