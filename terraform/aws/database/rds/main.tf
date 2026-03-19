# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-rds"
    },
    var.additional_tags
  )

  # Prod environments automatically get deletion protection and final snapshot
  is_prod             = var.environment == "prod"
  deletion_protection = local.is_prod ? true : var.deletion_protection
  skip_final_snapshot = local.is_prod ? false : var.skip_final_snapshot
}

# ─────────────────────────────────────────────────────────────
# RDS SUBNET GROUP
# RDS requires a subnet group spanning at least 2 AZs
# ─────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-rds-subnet-group"
  description = "RDS subnet group for ${var.client_name} ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-rds-subnet-group"
  })
}

# ─────────────────────────────────────────────────────────────
# RDS INSTANCE
# ─────────────────────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-rds"

  # Engine
  engine         = var.engine
  engine_version = var.engine_version

  # Sizing
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  # Database
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false  # never expose RDS to the internet

  # High availability
  multi_az = var.multi_az

  # Storage
  storage_type      = "gp3"
  storage_encrypted = true  # always encrypt at rest

  # Backups
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"  # 3-4am UTC
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Protection
  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = local.skip_final_snapshot
  final_snapshot_identifier = local.skip_final_snapshot ? null : "${local.name_prefix}-rds-final-snapshot"

  # Performance
  performance_insights_enabled = local.is_prod

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-rds"
  })
}
