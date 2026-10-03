# Infrastructure as Code

This is a build plan for provisioning
the AWS deployment with **OpenTofu**, not the OpenTofu source itself — it
names the resources, the order they depend on each other in, and the
non-obvious arguments that are easy to get wrong. Read `Architecture.md` for
*what* the system is and *why* it's shaped this way; read `aws-architecture.md`
for the AWS-specific reasoning behind each choice below. This doc is just
*how to build it*.

## Toolchain

- **OpenTofu (`tofu`), not Terraform.** Written fresh, not migrated — if
  you've only used Terraform before, the only things that actually differ in
  practice: the binary is `tofu` (every subcommand is identical), `.tf` files
  and provider blocks (`source = "hashicorp/aws"`) work completely unchanged,
  and HCP Terraform Cloud isn't usable as a backend (not relevant here — see
  below). OpenTofu has a few extras Terraform's open CLI doesn't (state
  encryption, `provider for_each`) — none are used here, to keep the option
  of moving to plain Terraform open if that's ever useful.
- **State backend: S3 + DynamoDB lock table.** Standard for AWS, identical
  syntax in both tools. Put the state bucket and lock table in their own
  small bootstrap module, applied once, before anything else.
- **Module layout:** one root module per environment (just one environment
  for now), composed of local modules per component (`network`, `data`,
  `bff`, `api`, `worker`, `queue-metrics`, `edge`). Keeps each component's
  resources reviewable on their own, and mirrors the component breakdown
  below.

## Build order (dependency chain)

1. **Networking** — VPC, public + private subnets across 2 AZs minimum,
   Internet Gateway, NAT Gateway, route tables, the S3 Gateway VPC Endpoint.
   Everything else lives inside this.
2. **Data layer** — Aurora Serverless v2 cluster, ElastiCache replication
   group, the S3 bucket. These take real time to provision (Aurora
   especially) and nothing else can start until they exist.
3. **Compute** — ECS cluster, task definitions, services, Service Connect
   namespace, autoscaling targets/policies.
4. **Edge** — CloudFront distribution(s), WAF Web ACL + association, ALB +
   listener + target group.
5. **Observability/automation glue** — the queue-depth Lambda, CloudWatch
   alarms, SNS topic + Slack subscription.

## Networking

- VPC with **public subnets** (ALB, NAT Gateway) and **private subnets**
  (everything else — Fargate tasks, Aurora, ElastiCache) across at least 2
  AZs.
- **One NAT Gateway** (single-AZ, cost-optimized choice, accepted trade-off —
  see `aws-architecture.md`). Both the worker's and the API's private
  subnets route `0.0.0.0/0` through it, for their calls to Vertex AI, Voyage,
  and Imejis.
- **S3 Gateway VPC Endpoint** (`aws_vpc_endpoint`, `vpc_endpoint_type =
  "Gateway"`, associated with the private route tables). Free, and keeps
  API/worker ↔ S3 traffic off the NAT Gateway entirely — route table
  association, not a security group concern.

## Backend-for-Frontend & Web Server

- `aws_ecs_service` on Fargate, **min 2 tasks, spread across both AZs**, in
  the private subnets.
- `aws_lb` (ALB) in the **public** subnets + `aws_lb_target_group` +
  `aws_lb_listener` (443, ACM cert) pointed at the service.
- `aws_appautoscaling_target` (min 2, max 5) with **two**
  `aws_appautoscaling_policy` target-tracking resources on the same target —
  one on `ALBRequestCountPerTarget`, one on `ECSServiceAverageCPUUtilization`.
  Both active simultaneously is intentional, not redundant — see
  `aws-architecture.md`.
- `aws_cloudwatch_metric_alarm` on the ALB's `TargetResponseTime` p95/p99
  (CloudWatch `ExtendedStatistic`, e.g. `p95`/`p99`) for the latency
  monitoring requirement.
- Two security groups:
  - **Task SG**: inbound only from the ALB's SG, on the container port.
  - **ALB SG**: inbound 443 only from CloudFront's managed prefix list —
    `data "aws_ec2_managed_prefix_list" "cloudfront"` (name
    `com.amazonaws.global.cloudfront.origin-facing`), referenced in the
    security group rule's `prefix_list_ids`, not a literal CIDR list. This is
    not an EC2-to-EC2 "security group reference" — CloudFront has no VPC
    presence, so the prefix list is the actual mechanism.

## REST API

- Same Fargate shape as the BFF (min 2, max 5, both AZs), **no public ALB**.
- `aws_service_discovery_http_namespace` for ECS Service Connect; the
  service's `service_connect_configuration` block exposes it as a private
  DNS name the BFF's tasks resolve directly.
- `aws_appautoscaling_target`/`policy`, same two-metric pattern as the BFF —
  but the request-count metric here is Service Connect's own `RequestCount`
  (via a customized metric specification), **not** `ALBRequestCountPerTarget`
  — there's deliberately no ALB in front of this service.
- Task SG: inbound only from the BFF's task SG, on the Service Connect port.

## Worker

- `aws_ecs_service`, **min 1 task**, Fargate **Spot** capacity provider, task
  placement spread across AZs (don't pin to one AZ — Spot capacity
  availability varies per AZ, and restricting to one increases interruption
  frequency).
- `aws_appautoscaling_target` (min 1, max 5) with a target-tracking policy on
  a **customized metric specification** pointed at the custom namespace/metric
  the queue-depth Lambda publishes (see below) — there's no native
  queue-depth CloudWatch metric for Redis the way SQS publishes one for free,
  which is the entire reason the Lambda exists.
- Task SG: outbound to the NAT Gateway (external APIs), outbound to
  ElastiCache's SG, outbound to Aurora's SG, outbound to the S3 Gateway
  Endpoint's prefix list. No inbound rules needed — it only ever initiates
  connections.

## PostgreSQL — Aurora Serverless v2

- `aws_rds_cluster` with `engine_mode = "provisioned"` and a
  `serverlessv2_scaling_configuration` block: `min_capacity = 0.5`,
  `max_capacity = 1` (deliberately capped low for now — see
  `aws-architecture.md`'s pending decisions).
- One `aws_rds_cluster_instance` with `instance_class = "db.serverless"`.
- Security group: inbound 5432 only from the API's and worker's task SGs.
- `pgvector` extension: created by the app's own `migrate` step
  (`CREATE EXTENSION IF NOT EXISTS vector`), not by OpenTofu — nothing to do
  here beyond provisioning the cluster itself.

## Redis — ElastiCache

- `aws_elasticache_replication_group`, **cluster mode disabled**
  (`automatic_failover_enabled = false`, `num_cache_clusters = 1` — i.e. no
  read replica, matching the single-AZ decision), smallest reasonable node
  type (`cache.t4g.small` or similar).
- **Not** `aws_elasticache_serverless_cache` — ElastiCache Serverless is
  incompatible with BullMQ (wrong `maxmemory-policy`, can't be changed). This
  is the one resource type in this whole plan that's easy to reach for by
  habit and would quietly break the worker.
- A custom `aws_elasticache_parameter_group` (family matching the engine
  version) explicitly setting `maxmemory-policy = noeviction` — the default
  isn't that, and BullMQ needs it.
- Security group: inbound 6379 only from the API's and worker's task SGs.

## Object Storage

- `aws_s3_bucket` — **private**, default encryption, versioning optional.
  Public access block left fully enabled (don't disable it for this bucket).
- `aws_cloudfront_origin_access_control` + an `aws_s3_bucket_policy`
  granting `s3:GetObject` only to that specific OAC's CloudFront service
  principal (scoped via the distribution's ARN in the policy condition, not
  a blanket CloudFront service-wide allow).
- Referenced as a second origin/behavior on the same CloudFront distribution
  used for the app (see Edge, below) — one distribution, one WAF Web ACL,
  one cert, rather than standing up a second distribution.

## Edge — CloudFront + WAF

- One `aws_cloudfront_distribution` with:
  - Default behavior → the BFF's ALB as a custom origin (dynamic, not
    cached, all headers forwarded — this is the path the SSE route and
    `/api/*` take).
  - A second behavior (e.g. `/cards/*`) → the S3 bucket via the OAC origin,
    cached normally (immutable, content-addressed keys).
- `aws_wafv2_web_acl`, **`scope = "CLOUDFRONT"`** — must be created via a
  provider alias pinned to `us-east-1`, regardless of which region the rest
  of the stack lives in. This is a real, easy-to-miss requirement for
  CloudFront-scoped Web ACLs specifically.
- Three rules: a rate-based rule (`aws_wafv2_web_acl` `rule` block with a
  `rate_based_statement`), and two AWS Managed Rule Group statements —
  `AWSManagedRulesCommonRuleSet` (Core Rule Set) and
  `AWSManagedRulesKnownBadInputsRuleSet`.
- `aws_wafv2_web_acl_association` — not used for CloudFront. CloudFront
  distributions associate a Web ACL via the distribution's own `web_acl_id`
  argument, not the separate association resource (that resource is for
  regional scope — ALB, API Gateway, AppSync — only).

## Queue-depth autoscaling — the Lambda

- `aws_lambda_function`, small Node/TS handler: connects to Redis, calls
  BullMQ's `queue.getWaitingCount()`, `PutMetricData` to a custom CloudWatch
  namespace (e.g. `Conflow/Worker`), metric name `QueueDepth`.
- `aws_cloudwatch_event_rule` (EventBridge schedule, `rate(1 minute)`) +
  `aws_lambda_permission` + `aws_cloudwatch_event_target` to trigger it.
- IAM role: `cloudwatch:PutMetricData`, plus whatever's needed to reach
  ElastiCache from inside the VPC (this Lambda needs VPC config — Redis is
  private — so it needs its own ENI in the private subnets and the
  ElastiCache SG opened to the Lambda's SG too).
- This entire resource — Lambda, EventBridge rule, the extra SG opening — is
  what disappears if the queue ever moves to SQS. See `aws-architecture.md`.

## Monitoring — Redis health → Slack

- `aws_cloudwatch_metric_alarm` on ElastiCache's `EngineCPUUtilization` and
  `DatabaseMemoryUsagePercentage`, threshold TBD from real usage.
- `aws_sns_topic`, alarm actions point at it.
- Slack delivery: **AWS Chatbot** (`aws_chatbot_slack_channel_configuration`)
  subscribed to the SNS topic is the no-custom-code option — a Lambda
  posting to a Slack webhook is the fallback if Chatbot's channel
  restrictions don't fit.

## Secrets & IAM

Sensitive config lives in **Secrets Manager**, split into two secrets by who
actually needs to read them — not one shared secret everything can see:

- **`api-token`** — the bearer token the BFF injects into its proxied calls
  to the API (`API_TOKEN` in today's `.env`). Only the BFF's task role can
  read this secret. The API's and worker's task roles have no grant on it at
  all — they don't need it, they never call themselves through the proxy.
- **`external-api-credentials`** — `VOYAGE_API_KEY`, `IMEJIS_API_KEY`, and
  the Vertex AI credential (see below). Both the **API's and the worker's**
  task roles can read this one — the API needs it directly for its
  synchronous edit/single-card routes, not just the worker.

Three separate `aws_iam_role` resources (one per service), each with its own
`aws_iam_role_policy` scoping `secretsmanager:GetSecretValue` to only the
ARN(s) that service actually needs. The BFF's role has **no IAM path at all**
to the LLM/embedding credentials, even though it shares a VPC with
everything else — least-privilege by construction, not by convention. Worth
keeping these as two distinct secrets rather than consolidating later for
convenience; that consolidation is exactly how this boundary quietly
disappears.

Non-secret config (`MODEL_CHANNEL`, `MODEL_ID`, `VERTEX_PROJECT`,
`VERTEX_LOCATION`, `LLM_TIMEOUT_MS`, and similar) stays as plain
task-definition `environment` entries — no reason to pay a Secrets Manager
API call for values that aren't sensitive.

**S3 access keys disappear entirely.** `S3_ACCESS_KEY`/`S3_SECRET_KEY` in
today's `.env` become unnecessary in AWS — the API's and worker's task roles
get direct `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` IAM permissions on
the bucket instead. No credential material to store or rotate for this one
at all.

**Vertex AI is the one credential that isn't a plain API key**, worth
deciding before implementation rather than glossing over as "just another
secret." Today it's Google ADC — `gcloud auth application-default login` run
on the host, mounted into the container as a file. Two real options in AWS:

- Download a GCP service account JSON key and store it in
  `external-api-credentials` — simplest, but it's a long-lived static
  credential sitting in Secrets Manager.
- **GCP Workload Identity Federation with AWS as the identity source** — AWS
  is one of GCP's built-in supported external identity provider types; the
  API's/worker's IAM role identity federates straight to a GCP service
  account, with no static key stored anywhere. More setup (a GCP-side
  identity pool/provider trusting those specific AWS role ARNs), but it's
  the better practice, and the kind of thing worth doing once rather than
  retrofitting after a key's already been generated and distributed.

## Container registry access

Images are built and tagged via `docker-bake.hcl` in the OSS repo and pushed
to GHCR (`ghcr.io/conflow-oss/conflow/server:1`,
`ghcr.io/conflow-oss/conflow/webserver:1`), not ECR. The GHCR packages are
**public** — Conflow is open source, so there's no reason to lock them down —
which means task definitions reference the image directly
(`image = "ghcr.io/conflow-oss/conflow/server:1"`), nothing else needed. No
`repositoryCredentials`, no Secrets Manager secret, no extra IAM on the task
execution role for this. (If that ever changes — a private fork, a
proprietary build — the fallback is `repositoryCredentials.credentialsParameter`
pointing at an `aws_secretsmanager_secret` holding a GHCR PAT with
`read:packages`, plus `secretsmanager:GetSecretValue` on the execution role.)

## Known gaps, carried over on purpose

- **Fargate Spot is only safe because the worker's job handler is already
  idempotent/resumable** (built in the OSS repo — checks run status, resumes
  from stored checkpoints, Postgres advisory lock against double-execution).
  If that code ever regresses, Spot stops being a safe choice here.
- **ElastiCache has no read replica yet** — a single node failure needs a
  manual replace-and-reconcile. Deferred deliberately; see
  `aws-architecture.md`.
- **Aurora's max capacity (1 ACU) is deliberately tight** — fine for current
  load, a real ceiling the moment traffic grows. Revisit before it bites.
