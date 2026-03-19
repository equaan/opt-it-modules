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
# STORAGE CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "storage_suffix" {
  description = "Short suffix for the storage account name. Combined with client and environment. Lowercase alphanumeric only, max 5 chars. Example: data, app, bkp"
  type        = string
  default     = "store"

  validation {
    condition     = can(regex("^[a-z0-9]{1,5}$", var.storage_suffix))
    error_message = "storage_suffix must be lowercase alphanumeric only, max 5 characters."
  }
}

variable "account_replication_type" {
  description = "Storage replication type. LRS: single region (dev), GRS: geo-redundant (prod). Options: LRS, GRS, RAGRS, ZRS."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "account_replication_type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "enable_versioning" {
  description = "Whether to enable blob versioning. Recommended for prod. Allows recovery of deleted or overwritten blobs."
  type        = bool
  default     = false
}

variable "enable_soft_delete" {
  description = "Whether to enable soft delete for blobs. Deleted blobs are retained for retention_days before permanent deletion."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted blobs. Only applies if enable_soft_delete = true."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days must be between 1 and 365."
  }
}

variable "container_names" {
  description = "List of blob container names to create inside the storage account. Example: [\"uploads\", \"backups\"]"
  type        = list(string)
  default     = ["default"]
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
