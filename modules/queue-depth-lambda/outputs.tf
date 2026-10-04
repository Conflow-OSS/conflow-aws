output "function_name" {
  value = aws_lambda_function.this.function_name
}

output "security_group_id" {
  description = "Pass this into modules/elasticache-redis's allowed_security_group_ids so Redis accepts connections from this Lambda."
  value       = aws_security_group.this.id
}
