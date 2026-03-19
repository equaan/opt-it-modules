# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard Opt IT variables present in every module
# ─────────────────────────────────────────────────────────────

variable "client_name" {
  description = "Name of the client this infrastructure belongs to. Lowercase alphanumeric and hyphens only. Example: acme-corp"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric characters and hyphens only."
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
  description = "Version of this module being used. Injected by the Backstage template."
  type        = string
  default     = "1.0.0"
}

# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard Azure variables present in every module
# ─────────────────────────────────────────────────────────────

variable "location" {
  description = "Azure region. Passed from module.resource_group.location"
  type        = string
}

variable "subscription_id" {
  description = "Azure Subscription ID."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID."
  }
}

variable "resource_group_name" {
  description = "Resource group name. Passed from module.resource_group.resource_group_name"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# VNET DEPENDENCY — for private access
# ─────────────────────────────────────────────────────────────

variable "delegated_subnet_id" {
  description = "ID of a subnet delegated to the database service. Must be an empty subnet — cannot contain other resources. Passed from module.vnet.private_subnet_ids[1]"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone for the flexible server. Must be created separately and linked to the VNet. Example: /subscriptions/.../privateDnsZones/acme-corp.postgres.database.azure.com"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# DATABASE ENGINE
# ─────────────────────────────────────────────────────────────

variable "db_engine" {
  description = "Database engine to provision. postgres = PostgreSQL Flexible Server, mysql = MySQL Flexible Server."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.db_engine)
    error_message = "db_engine must be one of: postgres, mysql."
  }
}

variable "db_version" {
  description = "Database engine version. PostgreSQL: 14, 15, 16. MySQL: 8.0."
  type        = string
  default     = "15"
}

variable "sku_name" {
  description = "SKU for the flexible server. Format: {tier}_{family}_{vcores}. dev: B_Standard_B1ms, prod: GP_Standard_D2s_v3"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB. Minimum 32768 (32 GB). Example: 32768, 65536, 131072."
  type        = number
  default     = 32768

  validation {
    condition     = var.storage_mb >= 32768
    error_message = "storage_mb must be at least 32768 (32 GB)."
  }
}

variable "admin_username" {
  description = "Administrator username for the database server."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = !contains(["admin", "administrator", "root", "guest", "azure_superuser"], var.admin_username)
    error_message = "admin_username cannot use reserved names: admin, administrator, root, guest, azure_superuser."
  }
}

variable "admin_password" {
  description = "Administrator password. Minimum 8 chars, must include uppercase, lowercase, number, and special character. Never commit this — use TF_VAR_admin_password or a secrets manager."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "admin_password must be at least 8 characters."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups. Minimum 7 for prod."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "geo_redundant_backup" {
  description = "Whether to enable geo-redundant backups. Recommended for prod. Additional cost applies."
  type        = bool
  default     = false
}

variable "high_availability_mode" {
  description = "High availability mode. Disabled: no HA, SameZone: standby in same zone, ZoneRedundant: standby in different zone. Recommended ZoneRedundant for prod."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Disabled", "SameZone", "ZoneRedundant"], var.high_availability_mode)
    error_message = "high_availability_mode must be Disabled, SameZone, or ZoneRedundant."
  }
}

variable "initial_db_name" {
  description = "Name of the initial database to create on the server."
  type        = string
  default     = "appdb"
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
