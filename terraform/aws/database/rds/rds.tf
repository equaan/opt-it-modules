module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.1.0"

  identifier = "${{ values.client_name }}-db"

  engine               = "postgres"
  engine_version       = "15.7"
  family               = "postgres15"
  major_engine_version = "15"
  
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = "appdb"
  username = "dbadmin"
  port     = 5432

  manage_master_user_password = true

  # Attach to VPC if deployed
  # db_subnet_group_name   = module.vpc.database_subnet_group_name
  # vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
  deletion_protection = false
}
