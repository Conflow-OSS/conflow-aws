resource "aws_rds_cluster" "this" {
  cluster_identifier = var.name
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = var.engine_version
  database_name      = "conflow"
  master_username    = var.master_username

  # AWS creates and rotates the master password in Secrets Manager itself —
  # OpenTofu never sees or stores it. See IaC.md's Secrets & IAM section.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  storage_encrypted         = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"
  apply_immediately         = var.apply_immediately

  serverlessv2_scaling_configuration {
    min_capacity = var.min_capacity
    max_capacity = var.max_capacity
  }

  # pgvector is created by the app's own migrate step
  # (CREATE EXTENSION IF NOT EXISTS vector), not here — see IaC.md.
}
