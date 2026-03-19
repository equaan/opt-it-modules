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

variable "location" {
  description = "GCS bucket location. Can be a region (us-central1), multi-region (US, EU, ASIA), or dual-region. Multi-region recommended for prod."
  type        = string
  default     = "US"
}

variable "bucket_suffix" {
  description = "Suffix appended to bucket name. Lowercase alphanumeric and hyphens. Example: assets, backups, uploads"
  type        = string
  default     = "storage"
}

variable "storage_class" {
  description = "Storage class. STANDARD: frequent access, NEARLINE: monthly, COLDLINE: quarterly, ARCHIVE: yearly."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "enable_versioning" {
  description = "Whether to enable object versioning. Recommended for prod."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Days to retain soft-deleted objects. 0 to disable soft delete."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 0 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 0 and 90."
  }
}

variable "force_destroy" {
  description = "Allow bucket destruction even with objects inside. Set to false for prod."
  type        = bool
  default     = false
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
