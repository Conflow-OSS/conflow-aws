variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets — Redis is private, so this Lambda needs its own ENI there."
  type        = list(string)
}

variable "redis_host" {
  type = string
}

variable "redis_port" {
  type    = number
  default = 6379
}

variable "queue_name" {
  description = "BullMQ queue name, e.g. \"content-jobs\" — must match the app's QUEUE_NAME."
  type        = string
}

variable "metric_namespace" {
  type    = string
  default = "Conflow/Worker"
}

variable "metric_name" {
  type    = string
  default = "QueueDepth"
}

variable "schedule_rate_minutes" {
  type    = number
  default = 1
}

variable "log_retention_days" {
  type    = number
  default = 14
}
