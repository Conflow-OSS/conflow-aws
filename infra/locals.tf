data "aws_caller_identity" "current" {}

locals {
  bff_name    = "${var.name}-bff"
  api_name    = "${var.name}-api"
  worker_name = "${var.name}-worker"

  # Globally unique without the human having to invent a suffix.
  cards_bucket_name = "${var.name}-cards-${data.aws_caller_identity.current.account_id}"

  # The API and worker share one image (packages/server/Dockerfile) with
  # different commands — a fixed fact of that image, not something that
  # varies per environment, so it's a local, not a variable.
  #
  # Both commands also do two things the app itself doesn't do today,
  # entirely on the infra side so no app code has to change:
  #   - write the Vertex service-account key (injected as a secret-sourced
  #     env var, see secrets.tf) to a file and point
  #     GOOGLE_APPLICATION_CREDENTIALS at it — today's app only knows ADC
  #     via a file (gcloud auth application-default login, mounted in);
  #     there's nowhere on Fargate to mount that from.
  #   - assemble DATABASE_URL from DB_HOST/DB_PORT/DB_USER/DB_NAME (plain
  #     env) + DB_PASSWORD (a secret) — Terraform can never see Aurora's
  #     AWS-managed master password to build the full URL itself (that's
  #     the entire point of manage_master_user_password), so the one
  #     connection-string env var the app expects has to be assembled at
  #     container start instead.
  entrypoint_prelude = join(" && ", [
    "printf '%s' \"$VERTEX_SERVICE_ACCOUNT_KEY\" > /tmp/vertex-key.json",
    "export GOOGLE_APPLICATION_CREDENTIALS=/tmp/vertex-key.json",
    "export DATABASE_URL=\"postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME\"",
  ])

  api_command    = ["sh", "-c", "${local.entrypoint_prelude} && exec node dist/api/server.js"]
  worker_command = ["sh", "-c", "${local.entrypoint_prelude} && exec node dist/worker/index.js"]
}
