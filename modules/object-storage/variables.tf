variable "name" {
  description = "Bucket name — must be globally unique across all of AWS, e.g. \"conflow-staging-cards\"."
  type        = string
}

variable "versioning_enabled" {
  type    = bool
  default = false
}
