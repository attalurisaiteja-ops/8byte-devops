# ============================================================
# environments/production/terraform.tfvars
# ============================================================

aws_region   = "us-east-1"
project_name = "8byte-devops"
environment  = "production"

# VPC
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.10.0/24", "10.1.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# ECS — higher counts for prod
app_port      = 3000
desired_count = 2
instance_type = "t3.small"

# RDS — Multi-AZ for prod HA
db_name              = "appdb"
db_username          = "dbadmin"
db_instance_class    = "db.t3.small"
db_allocated_storage = 50
db_multi_az          = true

common_tags = {
  Project     = "8byte-devops"
  Environment = "production"
  ManagedBy   = "Terraform"
  Owner       = "DevOps"
}
