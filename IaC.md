# Infrastructure as Code

This is a build plan for provisioning
the AWS deployment with **OpenTofu**, not the OpenTofu source itself — it
names the resources, the order they depend on each other in, and the
non-obvious arguments that are easy to get wrong. Read `Architecture.md` for
*what* the system is and *why* it's shaped this way; read `aws-architecture.md`
for the AWS-specific reasoning behind each choice below. This doc is just
*how to build it*. Read `prerequisites.md` first if you haven't yet — nothing
below will run until the manual setup it describes (state backend, the IAM
identity running OpenTofu, the Cloudflare zone/token) already exists.

## Toolchain

- **OpenTofu (`tofu`), not Terraform.** Written fresh, not migrated — if
  you've only used Terraform before, the only things that actually differ in
  practice: the binary is `tofu` (every subcommand is identical), `.tf` files
  and provider blocks (`source = "hashicorp/aws"`) work completely unchanged,
  and HCP Terraform Cloud isn't usable as a backend (not relevant here — see
  below). OpenTofu has a few extras Terraform's open CLI doesn't (state
  encryption, `provider for_each`) — none are used here, to keep the option
  of moving to plain Terraform open if that's ever useful. **Requires
  OpenTofu >= 1.11** specifically for write-only secret arguments (see
  Secrets & IAM below) — don't pick an older version for this project.
- **Every version is pinned exactly, in exactly one place — no `~>` ranges,
  no re-pinning per module.** `required_version` (OpenTofu itself) and
  `required_providers` (`aws`, `cloudflare`) are pinned with `=` constraints
  **only in each environment's own `versions.tf`** — `environments/staging`
  and `environments/production` each declare the identical exact versions,
  and that's the single source of truth for both. Every `modules/*` and
  `infra` module still declares which providers it uses (so OpenTofu can
  validate the configuration on its own), but with **no version
  constraint** — this is the standard, HashiCorp-recommended split for
  reusable modules: a hard pin inside a module forces every consumer of
  that module to match it exactly, which is fine for a module with a single
  owner but becomes a needless source of conflicts to maintain across a
  dozen files for no benefit, since the two root modules already guarantee
  only one version is ever actually used. A registry *module* (not
  provider) source, like `terraform-aws-modules/vpc/aws` below, is the one
  exception — module version pinning has no inheritance mechanism, so it's
  pinned directly on the `module` block that calls it, inside
  `modules/network` itself, the one place that calls it.
  The accepted trade-off of pinning at all: no automatic patch/security
  pickup — a bump is always a deliberate, reviewed change, same philosophy
  as committing `.terraform.lock.hcl`. Confirmed via each project's GitHub
  releases API on 2026-10-03 (the Terraform Registry's own module/provider
  pages are JS-rendered and didn't return useful content through automated
  fetching, so GitHub was the more reliable source):
  - OpenTofu: **`1.13.1`**
  - `hashicorp/aws`: **`6.67.0`**
  - `cloudflare/cloudflare`: **`5.27.0`**
  - `terraform-aws-modules/vpc/aws` (pinned in `modules/network/main.tf`,
    both the `vpc` and `vpc-endpoints` submodule calls together): **`6.7.3`**
    — confirmed compatible with `aws` provider `6.67.0` (its `versions.tf`
    requires `aws >= 6.28`); its `v6.0.0` major bump's *only* breaking
    change was raising that same floor from `v5`, not an interface
    redesign, so the variable/output names used in `modules/network` are
    unchanged from the `v5.x` line.
- **State backend: S3 + DynamoDB lock table**, provisioned by a small,
  idempotent **Bash script** (`bootstrap/bootstrap.sh`, plain AWS CLI calls —
  `create-bucket`/`put-bucket-versioning`/`put-bucket-encryption`/
  `put-public-access-block`/`create-table`, each checking whether its
  resource already exists before creating it), **not an OpenTofu module.**
  Deliberately not Terraform/OpenTofu here: the backend's own storage can't
  itself depend on the backend it's creating, so a Terraform module in that
  position only trades one chicken-and-egg problem (where does *its* state
  live) for the appearance of consistency. A script has no state of its own
  to lose track of — rerunning it is always safe, and "has this already
  been applied?" is answered by checking AWS directly, not a state file.
- **Tagging: every taggable AWS resource gets `environment` (`staging` |
  `production`) and `product = "conflow"`**, applied once via each
  environment's `aws` provider `default_tags` block (both the default
  region provider and the `us-east-1` alias) rather than a `tags = {...}`
  argument repeated on every resource — default tags propagate to anything
  built through that provider, including resources created by
  `terraform-aws-modules/vpc/aws` and by nested modules that receive the
  provider via a passed-down `providers = {}` block. Two caveats worth
  knowing going in: Auto Scaling Groups have historically been the one AWS
  resource type `default_tags` doesn't reach (moot here — this stack uses
  Application Auto Scaling on ECS services, not EC2 ASGs, so it isn't hit),
  and spot-check new/unusual resource types (the queue-depth Lambda, the
  WAF Web ACL, the Chatbot Slack config) during implementation rather than
  assuming every single one inherits the provider default — add an explicit
  `tags` argument on any that don't. Cloudflare's provider has no equivalent
  concept for DNS records, so `cloudflare_record` resources stay untagged —
  a platform limitation, not an oversight.
- **Module layout:** `environments/staging` and `environments/production`
  are the two root modules (one per environment), each composing a shared,
  non-root `infra` module. `infra` imports local modules per component —
  `network`, `ecs-cluster`, `ecs-service`, `alb`, `aurora-postgres`,
  `elasticache-redis`, `object-storage`, `dns`, `waf`, `cdn`,
  `queue-depth-lambda`, `alerting` — plus a handful of resources declared
  directly in `infra` itself where they're pure glue between two already-
  complete modules (the S3 bucket policy wiring in CloudFront's OAC, the
  final Cloudflare CNAME, the Secrets Manager secrets + their IAM grants).
  `ecs-service` is one reusable module called three times (BFF, API,
  worker), not three separate modules — the differences between them (load
  balancer vs Service Connect vs neither, Fargate vs Fargate Spot, which
  autoscaling metrics) are all just different inputs to the same module.
  Keeps each component's resources reviewable on their own, and mirrors the
  component breakdown below.

- **No `main.tf` grab-bag.** Inside every module, resources are split across
  topically-named files (`cluster.tf`, `security-groups.tf`,
  `target-groups.tf`, `networking.tf`, and so on) grouped by what they're
  actually doing, not dumped into one file by convention-of-the-name
  `main.tf`. `variables.tf` and `outputs.tf` stay as their own files
  regardless.

## Build order (dependency chain)

1. **Networking** — VPC, public + private subnets across 2 AZs minimum,
   Internet Gateway, NAT Gateway, route tables, the S3 Gateway VPC Endpoint.
   Everything else lives inside this.
2. **Data layer** — Aurora Serverless v2 cluster, ElastiCache replication
   group, the S3 bucket. These take real time to provision (Aurora
   especially) and nothing else can start until they exist.
3. **Compute** — ECS cluster, task definitions, services, Service Connect
   namespace, autoscaling targets/policies.
4. **DNS & TLS** — the ACM certificate (`us-east-1`) and its Cloudflare
   validation records. Must reach `ISSUED` before CloudFront can reference
   it, so this has to land before step 5.
5. **Edge** — CloudFront distribution(s), WAF Web ACL + association, ALB +
   listener + target group, then the final Cloudflare CNAME pointed at the
   distribution.
6. **Observability/automation glue** — the queue-depth Lambda, CloudWatch
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
  `serverlessv2_scaling_configuration` block: `min_capacity = 0` in **both**
  environments (true scale-to-zero — Aurora bills nothing while idle, and
  idle is most of the time for this workload), `max_capacity = 1`
  (deliberately capped low for now — see `aws-architecture.md`'s pending
  decisions). `min_capacity = 0` needs an Aurora PostgreSQL engine version
  that actually supports 0-ACU scaling — pin and confirm the exact minimum
  version when writing the `aurora-postgres` module rather than assuming
  whatever version gets picked qualifies. Verify the real cold-start latency
  from a genuine zero (not the sub-second "paused but warm" case) during
  staging testing, and record what was actually observed instead of
  assuming a number.
- One `aws_rds_cluster_instance` with `instance_class = "db.serverless"`.
- Security group: inbound 5432 only from the API's and worker's task SGs.
- `pgvector` extension: created by the app's own `migrate` step
  (`CREATE EXTENSION IF NOT EXISTS vector`), not by OpenTofu — nothing to do
  here beyond provisioning the cluster itself.

## Redis — ElastiCache

- **Engine: Valkey, not Redis OSS** — a decision made during implementation,
  not in the original architecture docs. Redis OSS on ElastiCache is capped
  at version 7.1 going forward (versions 7.2+ are Valkey-only); AWS now
  recommends Valkey for every new ElastiCache deployment, it's cheaper, and
  it's a drop-in fork of Redis 7.2 at the wire-protocol level — BullMQ's
  `ioredis` client doesn't know or care which one it's talking to. `engine
  = "valkey"`, `engine_version = "8.2"`.
- `aws_elasticache_replication_group`, **cluster mode disabled**
  (`automatic_failover_enabled = false`, `num_cache_clusters = 1` — i.e. no
  read replica, matching the single-AZ decision), smallest reasonable node
  type (`cache.t4g.small` or similar).
- **Not** `aws_elasticache_serverless_cache` — ElastiCache Serverless is
  incompatible with BullMQ (wrong `maxmemory-policy`, can't be changed). This
  is the one resource type in this whole plan that's easy to reach for by
  habit and would quietly break the worker.
- A custom `aws_elasticache_parameter_group`, family `valkey8` (covers
  8.0/8.1/8.2 — confirmed against AWS's engine-specific-parameters docs),
  explicitly setting `maxmemory-policy = noeviction` — the default isn't
  that, and BullMQ needs it.
- Security group: inbound 6379 only from the API's and worker's task SGs.
- **Both at-rest and transit (TLS) encryption are on.**
  `transit_encryption_mode = "required"` — safe to set directly at
  creation for a brand-new replication group (the `preferred` →
  `required` two-step is only needed when migrating an *existing*,
  already-running unencrypted cluster, per the resource's own docs).
  `infra/`'s `REDIS_URL` uses `rediss://` (not `redis://`); `ioredis`
  turns that into a TLS connection on its own, with no other app code
  change needed in the common case. Not enabled here: `auth_token`
  (Redis AUTH) — this closes the encryption-in-transit gap specifically
  flagged as missing, not every possible Redis hardening option; AUTH is
  a separate, available enhancement if it's ever needed.

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

## DNS & TLS — Cloudflare

The domain's zone already lives in Cloudflare (see `prerequisites.md` —
OpenTofu never creates or migrates the zone itself), so the `dns` module's
only job is getting CloudFront a certificate it can present for that domain:

- `aws_acm_certificate`, `validation_method = "DNS"`, created through the
  **`us-east-1`-aliased** AWS provider — ACM certs for CloudFront must live
  in `us-east-1` regardless of which region the rest of the stack is in,
  same requirement as the WAF Web ACL below.
- One `cloudflare_record` per entry in the certificate's
  `domain_validation_options`, type `CNAME`, **`proxied = false`** — this is
  a DNS challenge response, not traffic, so it must stay unproxied or ACM's
  validator can't see it.
- `aws_acm_certificate_validation` depending on those records, so the
  module's `certificate_arn` output is only ever handed out already
  `ISSUED`.
- This module deliberately knows nothing about CloudFront — it only
  produces a validated certificate ARN for a given domain name. The
  *second*, separate Cloudflare record — the public one actually pointing
  the domain at CloudFront — is created later, directly in `infra`, once
  `cdn`'s distribution exists (see "Edge" below). Keeping these as two
  one-directional dependencies (`dns` → `cdn` → the final record) avoids
  `dns` and `cdn` needing to depend on each other.
- That final public record is **also unproxied** (`proxied = false`,
  DNS-only / grey-cloud in the Cloudflare dashboard) — Cloudflare is
  authoritative DNS here, nothing more. CloudFront keeps doing all the real
  work (TLS termination, caching, WAF). A proxied (orange-cloud) record
  would put Cloudflare's own edge in front of CloudFront's, which is not
  what this architecture wants.
- The ALB origin behind CloudFront stays **HTTP-only** — it never needs this
  certificate at all. That leg of the request never leaves AWS, and the
  custom-domain cert is only ever referenced by CloudFront's
  `viewer_certificate`, not by the ALB's listener.

## Edge — CloudFront + WAF

- One `aws_cloudfront_distribution` with:
  - Default behavior → the BFF's ALB as a custom origin (dynamic, not
    cached, all headers forwarded — this is the path the SSE route and
    `/api/*` take).
  - A second behavior (e.g. `/cards/*`) → the S3 bucket via the OAC origin,
    cached normally (immutable, content-addressed keys).
  - `aliases = [domain_name]` and a `viewer_certificate` block pointed at
    the `dns` module's validated `certificate_arn`
    (`ssl_support_method = "sni-only"`) instead of the CloudFront default
    certificate.
- Once the distribution exists, a standalone `cloudflare_record` in `infra`
  (type `CNAME`, unproxied) points `domain_name` at the distribution's
  `distribution_domain_name` — the step that actually makes the custom
  domain resolve to CloudFront.
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
- **`guardrail_policy_arns` defaults to the AWS-managed `AdministratorAccess`
  policy if left unset** (confirmed against the resource's own docs) — easy
  to miss since nothing about the argument being optional suggests that
  particular default. This channel only relays notifications, never runs
  interactive chat commands, so `modules/alerting` sets it explicitly to
  `ReadOnlyAccess` instead. The `iam_role_arn` role (what Chatbot itself
  assumes, separate from the guardrail) only needs
  `CloudWatchReadOnlyAccess`, just enough to enrich the alarm message it
  relays.

## Secrets & IAM

Sensitive config lives in **Secrets Manager**, split into two secrets by who
actually needs to read them — not one shared secret everything can see:

- **`api-token`** — the bearer token the BFF injects into its proxied calls
  to the API (`API_TOKEN`, identical in `packages/web/.env` and
  `packages/server/.env` today — confirmed directly against both files,
  correcting this doc's earlier claim that only the BFF needs it). **Both
  the BFF's and the API's** task roles can read this secret — the BFF to
  inject it, the API to validate incoming requests against it. The
  worker's role has no grant on it at all — it runs no HTTP server, so it
  never validates anything.
- **`external-api-credentials`** — `VOYAGE_API_KEY`, `IMEJIS_API_KEY`, and
  the Vertex AI credential (see below). Both the **API's and the worker's**
  task roles can read this one — the API needs it directly for its
  synchronous edit/single-card routes, not just the worker.

**None of these secrets' real values ever pass through a normal OpenTofu
argument, and that's deliberate, not incidental.** Any value a resource
argument reads from a variable — `.tfvars`, `-var`, environment-sourced or
not — gets written into the state file in plaintext as a normal resource
attribute by default. Marking the variable or argument `sensitive = true`
only redacts it from CLI output (`plan`/`apply` logs); it does nothing to
the state file itself, which still needs to be treated as a secret in its
own right regardless (encrypted backend, restricted IAM access to the state
bucket). The real fix here is OpenTofu 1.11+'s **write-only arguments**:
`aws_secretsmanager_secret_version` takes `secret_string_wo` (paired with a
required `secret_string_wo_version` integer) instead of plain
`secret_string` — OpenTofu sends the value to the AWS provider for exactly
this one apply and then discards its own copy, so it never lands in the
plan or the state file at all, the same guarantee `manage_master_user_password`
gives the Aurora password above, just applied by hand instead of by AWS.
Rotating a value means bumping `secret_string_wo_version` manually (there's
nothing stored to diff against, so that bump is what tells OpenTofu
something changed) — an accepted bit of manual bookkeeping in exchange for
the value never being persisted anywhere. This needs a sufficiently recent
AWS provider release; pin and confirm the exact minimum version when wiring
this up (see the provider-pinning note in Toolchain above).

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

**The Cloudflare API token is not an AWS secret at all.** It authenticates
the `cloudflare` provider itself, at `tofu plan`/`apply` time, on whoever's
machine is running OpenTofu — it has no reason to live in Secrets Manager or
in any task's environment, since no running service ever talks to
Cloudflare's API. Supplied via the `CLOUDFLARE_API_TOKEN` environment
variable in the apply shell; see `prerequisites.md` for how it's scoped.

## App integration notes

Facts confirmed directly against the app repo's real `.env` files and
Dockerfiles (not the `.env.example`s, which are stale on at least the
ports) while wiring `infra/`:

- **Real ports: BFF listens on `4000` (`PORT`), API on `5000`
  (`API_PORT`)** — not the `.env.example` defaults.
- **`packages/server/Dockerfile` builds one image for both the API and the
  worker** (`@content-engine/server`), default `CMD ["node",
  "dist/api/server.js"]`; the worker overrides it with `["node",
  "dist/worker/index.js"]`. A fixed fact of the image, not an
  environment-specific setting — `infra/`'s `local.api_command` /
  `local.worker_command` hardcode this rather than taking it as a
  variable.
- **The BFF reads `BACKEND_URL`, not any kind of "API base URL" name** —
  confirmed from `packages/web/.env.example`'s own comment.
- **`DATABASE_URL` and `REDIS_URL` are each a single connection-string env
  var** — the app has no split `DB_HOST`/`DB_PORT`/etc. contract. Redis
  has no auth token here, so `REDIS_URL` is just built directly as a plain
  Terraform string. Postgres is different: Aurora's
  `manage_master_user_password` means the password is never visible to
  Terraform at all (the entire reason to use it), so there's no way to
  assemble a complete `DATABASE_URL` as a plain resource argument. Fixed
  with a shell wrapper in the container `command`
  (`infra/locals.tf`'s `entrypoint_prelude`) that exports `DATABASE_URL`
  from the separately-injected `DB_HOST`/`DB_PORT`/`DB_USER`/`DB_NAME`
  (plain) and `DB_PASSWORD` (a secret) immediately before `exec`-ing the
  real start command. Entirely on the infra side — no app code changes.
- **Vertex auth today is ADC via a file mounted from the host**
  (`gcloud auth application-default login`), not an env var at all —
  there's nothing to mount on Fargate. Same wrapper writes the
  `VERTEX_SERVICE_ACCOUNT_KEY` secret's value to a file and sets
  `GOOGLE_APPLICATION_CREDENTIALS` to it before `exec`, so this is also
  resolved without touching app code.
- **Open question, not yet resolved — needs a look at the actual
  `MinioImageStore` implementation before a real deploy**: on AWS,
  `IMAGE_STORE=minio` is reused against real S3 (same generic
  `@aws-sdk/client-s3`-based code path, not a new "s3" mode), relying on
  the API's/worker's IAM task role rather than `S3_ACCESS_KEY`/
  `S3_SECRET_KEY`. This only works if `MinioImageStore`'s S3 client falls
  back to the AWS SDK's default credential provider chain when those env
  vars are unset, rather than unconditionally requiring them. Not
  verified in this pass.

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
