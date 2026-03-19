# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard Opt IT variables present in every module
# ─────────────────────────────────────────────────────────────

variable "client_name" {
  description = "Name of the client. Lowercase alphanumeric and hyphens only. Example: acme-corp"
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
# REQUIRED — Standard GCP variables
# ─────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP Project ID. Must match the project used in the vpc module."
  type        = string
}

# ─────────────────────────────────────────────────────────────
# VPC DEPENDENCY
# ─────────────────────────────────────────────────────────────

variable "vpc_name" {
  description = "Name of the VPC network. Passed from module.vpc.vpc_name"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# FIREWALL CONFIGURATION
#
# NOTE: GCP firewall rules work differently from AWS/Azure:
# - Rules apply to the entire VPC, not to a subnet or instance
# - VMs are targeted using NETWORK TAGS (string labels on VMs)
# - A VM only gets a rule if it has the matching network tag
# - This module creates standard tags: web-server, db-server
#   Apply these tags to your GCE instances accordingly
# ─────────────────────────────────────────────────────────────

variable "allowed_ssh_source_ranges" {
  description = "List of IP CIDR ranges allowed SSH access to VMs tagged with 'ssh-access'. Leave empty to disable SSH. Example: [\"203.0.113.10/32\"]. Never use 0.0.0.0/0."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_ssh_source_ranges, "0.0.0.0/0")
    error_message = "SSH from 0.0.0.0/0 is not permitted. Provide specific IP ranges."
  }
}

variable "allowed_http_source_ranges" {
  description = "IP ranges allowed HTTP (port 80) access to VMs tagged 'web-server'. Use [\"0.0.0.0/0\"] for public access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_source_ranges" {
  description = "IP ranges allowed HTTPS (port 443) access to VMs tagged 'web-server'. Use [\"0.0.0.0/0\"] for public access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_port" {
  description = "Database port to allow internal access. PostgreSQL: 5432, MySQL: 3306."
  type        = number
  default     = 5432

  validation {
    condition     = contains([3306, 5432], var.db_port)
    error_message = "db_port must be 3306 (MySQL) or 5432 (PostgreSQL)."
  }
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
