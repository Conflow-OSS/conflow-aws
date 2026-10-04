variable "name" {
  description = "Cluster name, e.g. \"conflow-staging\"."
  type        = string
}

variable "enable_container_insights" {
  description = "Turn on CloudWatch Container Insights for every service in this cluster."
  type        = bool
  default     = true
}
