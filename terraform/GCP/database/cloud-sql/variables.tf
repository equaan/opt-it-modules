variable "client_name" {
  description = "Client name. Lowercase alphanumeric and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Module version. Injected by Backstage."
  type        = string
  default     = "1.0.0"
}

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud SQL instance."
  type        = string
  default     = "us-central1"
}

variable "vpc_self_link" {
  description = "Self link of the VPC for private IP connectivity. Passed from module.vpc.vpc_self_link"
  type        = string
}

variable "db_engine" {
  description = "Database engine. postgres = PostgreSQL, mysql = MySQL."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.db_engine)
    error_message = "db_engine must be postgres or mysql."
  }
}

variable "db_version" {
  description = "Database version. PostgreSQL: POSTGRES_14, POSTGRES_15. MySQL: MYSQL_8_0."
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Cloud SQL machine tier. dev: db-f1-micro, staging: db-g1-small, prod: db-n1-standard-2. See https://cloud.google.com/sql/docs/postgres/instance-settings"
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size_gb" {
  description = "Storage disk size in GB. Minimum 10 GB."
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be at least 10 GB."
  }
}

variable "admin_password" {
  description = "Root/admin password for the database. Never commit this — use TF_VAR_admin_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "admin_password must be at least 8 characters."
  }
}

variable "backup_enabled" {
  description = "Whether to enable automated backups."
  type        = bool
  default     = true
}

variable "availability_type" {
  description = "Availability type. ZONAL: single zone (dev/staging), REGIONAL: multi-zone HA (prod)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
