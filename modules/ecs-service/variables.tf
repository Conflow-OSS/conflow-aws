variable "name" {
  description = "Service name, e.g. \"conflow-staging-api\". Also used as the container name and the CloudWatch log group suffix."
  type        = string
}

variable "cluster_name" {
  description = <<-EOT
    Plain name (not ARN) of the shared ECS cluster (modules/ecs-cluster)
    all three services run in. aws_ecs_service's `cluster` argument accepts
    either, but Application Auto Scaling's resource_id
    ("service/<cluster-name>/<service-name>") specifically needs the plain
    name — one variable, used both places, instead of two.
  EOT
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets the task's ENI runs in."
  type        = list(string)
}

variable "image" {
  description = "Full image reference, e.g. \"ghcr.io/conflow-oss/conflow/server:1\"."
  type        = string
}

variable "command" {
  description = "Container command override. The API and worker share the same \"server\" image but run different entrypoints — null keeps the image's own default CMD (the API's)."
  type        = list(string)
  default     = null
  nullable    = true
}

variable "container_port" {
  type = number
}

variable "app_protocol" {
  description = "ECS's appProtocol for the port mapping (\"http\"/\"http2\"/\"grpc\") — required for Service Connect's RequestCount and HTTPCode_Target_* metrics to be emitted at all, not just descriptive."
  type        = string
  default     = "http"
}

variable "cpu" {
  description = "Task-level vCPU units (Fargate's fixed cpu/memory combinations apply)."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task-level memory, MiB."
  type        = number
  default     = 512
}

variable "capacity_provider" {
  description = "FARGATE for the BFF/API, FARGATE_SPOT for the worker — see aws-architecture.md."
  type        = string
  default     = "FARGATE"

  validation {
    condition     = contains(["FARGATE", "FARGATE_SPOT"], var.capacity_provider)
    error_message = "capacity_provider must be \"FARGATE\" or \"FARGATE_SPOT\"."
  }
}

variable "min_count" {
  type = number
}

variable "max_count" {
  type = number
}

variable "autoscaling_metrics" {
  description = <<-EOT
    One entry per target-tracking policy. type = "cpu" needs only
    target_value. type = "alb_request_count" needs target_value and
    resource_label ("<alb-arn-suffix>/<target-group-arn-suffix>"). type =
    "custom_cloudwatch" needs target_value and customized_metric — this is
    also how Service Connect's own RequestCount metric is wired in (as a
    customized metric, not a predefined one), and how the worker's
    queue-depth metric is wired in. Passing 2 entries (e.g. cpu +
    alb_request_count) runs both target-tracking policies simultaneously —
    see IaC.md's Backend-for-Frontend section for why that's intentional,
    not redundant.
  EOT
  type = list(object({
    type           = string
    target_value   = number
    resource_label = optional(string)
    customized_metric = optional(object({
      metric_name = string
      namespace   = string
      statistic   = optional(string, "Average")
      dimensions  = optional(map(string), {})
    }))
  }))
  default = []
}

variable "load_balancer" {
  description = "Set only for the BFF — null means this service isn't fronted by an ALB (the API uses Service Connect instead, the worker isn't reached by anything)."
  type = object({
    target_group_arn = string
    container_port   = number
  })
  default  = null
  nullable = true
}

variable "service_connect" {
  description = <<-EOT
    Set for the API (exposes it as a private DNS name instead of sitting
    behind its own ALB) AND for the BFF (client-only — joins the namespace
    so it can resolve the API's name, but exposes nothing of its own).
    Leave port_name unset for a client-only participant: ECS Service
    Connect requires the CALLING service to carry its own
    service_connect_configuration too, just without a `service` block —
    it's not enough for only the API side to configure it. null means this
    service doesn't use Service Connect at all (the worker).
  EOT
  type = object({
    namespace_arn  = string
    port_name      = optional(string)
    discovery_name = optional(string)
  })
  default  = null
  nullable = true
}

variable "ingress_security_group_ids" {
  description = "Security groups allowed to reach this service's container_port. Empty for the worker — it only ever initiates connections, nothing reaches it."
  type        = list(string)
  default     = []
}

variable "secrets" {
  description = "Map of container env var name -> Secrets Manager secret ARN. Injected at container start by the execution role, never passed as a plain value — see IaC.md's Secrets & IAM section."
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Plain (non-secret) container env vars."
  type        = map(string)
  default     = {}
}

variable "task_role_policy_json" {
  description = "Extra IAM policy JSON granted to this service's role (e.g. S3 access for the API/worker) — merged alongside the auto-generated Secrets Manager read policy built from var.secrets. See IaC.md's note on using one combined role per service for both task and execution duties."
  type        = string
  default     = null
  nullable    = true
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "health_check_grace_period_seconds" {
  description = "Only relevant when load_balancer is set."
  type        = number
  default     = 60
}
