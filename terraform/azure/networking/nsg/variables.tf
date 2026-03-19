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

# ─────────────────────────────────────────────────────────────
# DEPENDENCIES — from resource_group and vnet modules
# ─────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Resource group name. Passed from module.resource_group.resource_group_name"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs to associate the public NSG with. Passed from module.vnet.public_subnet_ids"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs to associate the private NSG with. Passed from module.vnet.private_subnet_ids"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────
# NSG CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "allowed_ssh_source_prefixes" {
  description = "List of IP ranges allowed SSH (port 22) access to VMs. Leave empty to disable SSH. Example: [\"203.0.113.10/32\"]"
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_ssh_source_prefixes, "*") && !contains(var.allowed_ssh_source_prefixes, "0.0.0.0/0")
    error_message = "SSH access from * or 0.0.0.0/0 is not permitted. Provide specific IP ranges."
  }
}

variable "allowed_http_source_prefixes" {
  description = "List of IP ranges allowed HTTP (port 80) access. Use [\"*\"] for public-facing applications."
  type        = list(string)
  default     = ["*"]
}

variable "allowed_https_source_prefixes" {
  description = "List of IP ranges allowed HTTPS (port 443) access. Use [\"*\"] for public-facing applications."
  type        = list(string)
  default     = ["*"]
}

variable "db_port" {
  description = "Port the database listens on. PostgreSQL: 5432, MySQL: 3306, MSSQL: 1433."
  type        = number
  default     = 5432

  validation {
    condition     = contains([1433, 3306, 5432], var.db_port)
    error_message = "db_port must be 1433 (MSSQL), 3306 (MySQL), or 5432 (PostgreSQL)."
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
