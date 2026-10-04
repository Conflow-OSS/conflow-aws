output "certificate_arn" {
  description = "Always already ISSUED by the time this is readable, thanks to aws_acm_certificate_validation."
  value       = aws_acm_certificate_validation.this.certificate_arn
}
