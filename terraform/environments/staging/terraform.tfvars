# ============================================================
# environments/staging/terraform.tfvars
# ============================================================

aws_region   = "us-east-1"
project_name = "8byte-devops"
environment  = "staging"

# VPC
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

# ECS
app_port      = 3000
desired_count = 1
instance_type = "t3.micro"

# RDS
db_name              = "appdb"
db_username          = "dbadmin"
db_instance_class    = "db.t3.micro"
db_allocated_storage = 20
db_multi_az          = false

common_tags = {
  Project     = "8byte-devops"
  Environment = "staging"
  ManagedBy   = "Terraform"
  Owner       = "DevOps"
}
