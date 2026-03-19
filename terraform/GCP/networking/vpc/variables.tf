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
# REQUIRED — Standard GCP variables present in every module
#
# AUTHENTICATION:
#   This module uses Application Default Credentials (ADC).
#   For local development, run once:
#     gcloud auth application-default login
#   For CI/CD, use Workload Identity Federation.
#   Never use service account JSON key files — they are a
#   security risk and difficult to rotate.
# ─────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP Project ID where resources will be created. The project must already exist. Find it in GCP Console → Project selector. Example: acme-corp-prod-123456"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "GCP region for subnet creation. GCP VPCs are global but subnets are regional. Example: us-central1, europe-west1, asia-southeast1"
  type        = string
  default     = "us-central1"
}

# ─────────────────────────────────────────────────────────────
# VPC CONFIGURATION
#
# NOTE: GCP VPCs are GLOBAL — one VPC spans all regions.
# This is different from AWS (regional VPC) and Azure (regional VNet).
# Subnets are regional and defined within the global VPC.
# ─────────────────────────────────────────────────────────────

variable "public_subnet_cidr" {
  description = "CIDR range for the public subnet. Resources here have external IPs. Example: 10.0.1.0/24"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR range for the private subnet. Resources here have internal IPs only. Example: 10.0.10.0/24"
  type        = string
  default     = "10.0.10.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_subnet_cidr))
    error_message = "private_subnet_cidr must be a valid CIDR block."
  }
}

variable "enable_cloud_nat" {
  description = "Whether to enable Cloud NAT for private subnet internet egress. Recommended for prod. Without this, private VMs cannot reach the internet."
  type        = bool
  default     = false
}

variable "additional_labels" {
  description = "Additional GCP labels to apply to all resources. GCP uses labels instead of tags. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
