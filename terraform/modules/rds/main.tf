# ============================================================
# modules/rds/main.tf — RDS PostgreSQL (private, encrypted)
# ============================================================

resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = { Name = "${var.project_name}-${var.environment}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier        = "${var.project_name}-${var.environment}-postgres"
  engine            = "postgres"
  engine_version    = "15.4"
  instance_class    = var.db_instance_class
  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true # encryption at rest

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  multi_az               = var.db_multi_az
  publicly_accessible    = false # never expose DB to internet
  deletion_protection    = false # set true for production
  skip_final_snapshot    = true  # set false for production

  backup_retention_period = 7        # automated backups for 7 days
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled = true
  monitoring_interval          = 60 # Enhanced Monitoring every 60s

  tags = { Name = "${var.project_name}-${var.environment}-postgres" }
}
