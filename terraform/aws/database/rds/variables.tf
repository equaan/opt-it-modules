# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard Opt IT variables present in every module
# ─────────────────────────────────────────────────────────────

variable "client_name" {
  description = "Name of the client this infrastructure belongs to. Used in resource naming and tagging. Example: acme-corp"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric characters and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment. Controls resource sizing and behaviour."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Version of this module being used. Injected by the Backstage template."
  type        = string
  default     = "1.0.0"
}

# ─────────────────────────────────────────────────────────────
# SUBNET + SECURITY GROUP DEPENDENCIES
# ─────────────────────────────────────────────────────────────

variable "subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group. Minimum 2 required for Multi-AZ. Passed from module.subnets.private_subnet_ids"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs required for RDS subnet group."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the RDS instance. Passed from module.security_groups.database_security_group_id"
  type        = list(string)
}

# ─────────────────────────────────────────────────────────────
# RDS CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "engine" {
  description = "Database engine. Supported: mysql, postgres"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["mysql", "postgres"], var.engine)
    error_message = "engine must be one of: mysql, postgres."
  }
}

variable "engine_version" {
  description = "Database engine version. mysql: 8.0, postgres: 15.4"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "RDS instance class. dev: db.t3.micro, staging: db.t3.small, prod: db.t3.medium or larger."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage in GB for autoscaling. Set to 0 to disable autoscaling."
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username for the database."
  type        = string
  default     = "dbadmin"
}

variable "master_password" {
  description = "Master password for the database. Must be at least 8 characters. Store this in AWS Secrets Manager — never in git."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.master_password) >= 8
    error_message = "master_password must be at least 8 characters."
  }
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment for high availability. Recommended for prod. Additional cost applies."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups. 0 disables backups. Minimum 7 recommended for prod."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 0 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 0 and 35."
  }
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection. Automatically set to true for prod."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on deletion. Set to false for prod."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources in this module. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
