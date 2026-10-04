variable "name" {
  type = string
}

variable "rate_limit" {
  description = "Max requests from a single IP per 5-minute rolling window before it's blocked."
  type        = number
  default     = 2000
}
