output "service_name" {
  value = aws_ecs_service.this.name
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "role_arn" {
  description = "The single role used as both this service's task role and execution role."
  value       = aws_iam_role.this.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
