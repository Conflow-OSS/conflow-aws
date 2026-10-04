output "cluster_endpoint" {
  description = "Writer endpoint."
  value       = aws_rds_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  value = aws_rds_cluster.this.reader_endpoint
}

output "port" {
  value = aws_rds_cluster.this.port
}

output "database_name" {
  value = aws_rds_cluster.this.database_name
}

output "security_group_id" {
  value = aws_security_group.this.id
}

output "master_user_secret_arn" {
  description = "AWS-managed Secrets Manager secret holding the master password — see IaC.md's Secrets & IAM section."
  value       = aws_rds_cluster.this.master_user_secret[0].secret_arn
}
