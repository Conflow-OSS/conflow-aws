# Prerequisites

Everything in this doc has to exist *before* `tofu` can run anywhere in this
repo — none of it is created by OpenTofu itself. `bootstrap/` (the state
backend, below) is the one piece provisioned by this repo at all, and it's
deliberately a plain script rather than OpenTofu. Read this before
`IaC.md`.

## AWS account access

- A dedicated IAM user for running OpenTofu — **never the root user**.
  Something like `conflow-tofu-deployer`. Root is used exactly once, to
  create this user (and turn on account-level MFA), and never touched
  again after that.
- A custom least-privilege policy attached to that user, scoped to exactly
  the services this stack touches: EC2/VPC (network, security groups, NAT),
  ECS, Elastic Load Balancing, RDS, ElastiCache, S3, DynamoDB (the state
  lock table), CloudFront, WAFv2, Lambda, EventBridge, Secrets Manager,
  CloudWatch, SNS, Chatbot, STS, and IAM role/policy management — the last
  one scoped by a resource-name
  condition (e.g. role/policy names prefixed `conflow-`), not granted
  broadly. IAM permissions are unavoidable here since the stack provisions
  its own ECS task roles; the scoping is what keeps this from being
  `AdministratorAccess` in disguise.
- Programmatic access via a long-lived access key pair, used locally. This
  is a conscious trade-off for the current manual-apply workflow (see
  `IaC.md`) — revisit with IAM Identity Center or OIDC-based short-lived
  credentials once this moves to CI.

## State backend

- Run `bootstrap/bootstrap.sh` once, manually, with the deployer user's AWS
  CLI credentials active, before `init`-ing any `environments/*` root
  module. It's a plain Bash script (AWS CLI calls), **not** OpenTofu —
  deliberately, so the backend's own storage never has to depend on the
  backend it's creating. It provisions the S3 bucket (versioned, encrypted,
  public access blocked) and the DynamoDB lock table every
  `environments/*`'s `backend.tf` then points at.
- The script is idempotent — it checks whether the bucket/table already
  exist before creating them, so re-running it is always safe. There's no
  state file of its own to lose track of; "has this been run?" is answered
  by checking AWS directly.
- After running it, hand-copy the bucket name and table name into
  `environments/staging/backend.tf` and `environments/production/backend.tf`
  (different state **key**, same bucket and table).

## Cloudflare

- The domain's zone must already exist in Cloudflare and already be its
  authoritative DNS (nameservers already delegated there) — this repo does
  not create or migrate the zone.
- **Zone ID**: from the zone's overview page in the Cloudflare dashboard,
  supplied as a `cloudflare_zone_id` variable.
- **API Token** (not the legacy Global API Key): create one scoped to
  exactly `Zone:DNS:Edit` for that one zone — least privilege, not
  account-wide. Supplied via the `CLOUDFLARE_API_TOKEN` environment
  variable in whatever shell runs `tofu plan`/`apply` — never written into
  any `.tfvars` file, committed or not.

## Container images

- The GHCR images referenced by tag in each environment's `terraform.tfvars`
  (`ghcr.io/conflow-oss/conflow/server:<tag>`,
  `ghcr.io/conflow-oss/conflow/webserver:<tag>`) must already be built and
  pushed, via the app repo's `docker-bake.hcl`, before an `apply` that
  references that tag. OpenTofu only references existing images; it never
  builds or pushes them.

## External API credentials

- Voyage, Imejis, and Vertex AI credentials (and the BFF→API bearer token)
  are obtained outside this repo. OpenTofu writes them straight into their
  Secrets Manager secrets at `apply` time using **write-only** arguments
  (`secret_string_wo` on `aws_secretsmanager_secret_version`, requires
  OpenTofu >= 1.11 — see `IaC.md`), so even though the value is supplied
  through a local `.tfvars`-style input, it never gets written to the plan
  or the state file. Have these ready as a gitignored
  `secrets.auto.tfvars` (never committed) before the first `apply` that
  creates them — each secret resource has a paired version-number argument
  that has to be bumped by hand whenever a value is rotated, since OpenTofu
  keeps no copy of the old value to diff against.

## AWS quotas worth checking before the first apply

A lightly-used or newer AWS account can have default service quotas lower
than this stack needs — worth a quick check in the Service Quotas console,
not something OpenTofu verifies for you:
- Elastic IPs per region (the NAT Gateway needs one).
- Fargate on-demand and Fargate Spot vCPU limits (running BFF + API + worker
  across two environments adds up faster than it looks).
- VPCs per region, if this account already has others.

## Local tooling

- OpenTofu CLI **`1.13.1`** — the exact version pinned in each environment's
  `required_version` constraint (see `IaC.md`'s Toolchain section; every
  version in this repo is pinned exactly, not a range).
- AWS CLI configured with a profile for the deployer user above.
- `CLOUDFLARE_API_TOKEN` exported in the shell that runs `tofu
  plan`/`apply`.
- A local, gitignored `secrets.auto.tfvars` per environment holding the
  external API credentials and bearer token (see above) — present before
  the first `apply` that creates those secrets, not needed on every
  subsequent `apply` unless a value is rotating.
- Node.js (any version matching `modules/queue-depth-lambda/lambda`'s
  runtime — `nodejs22.x`) and npm, to build that Lambda's dependencies:
  `cd modules/queue-depth-lambda/lambda && npm ci`. Needed before the first
  `apply` that creates it, and again whenever its `package.json` changes —
  `data.archive_file` only zips whatever's already on disk, it doesn't run
  `npm install` itself (deliberately no `local-exec` provisioner for this —
  see that module's `packaging.tf`).
