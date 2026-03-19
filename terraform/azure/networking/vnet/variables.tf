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
  description = "Azure region. Must match the resource group location. Passed from module.resource_group.location"
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
# RESOURCE GROUP DEPENDENCY
# Passed from module.resource_group outputs
# ─────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Name of the resource group to create the VNet in. Passed from module.resource_group.resource_group_name"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# VNET CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "vnet_address_space" {
  description = "Address space for the VNet. List of CIDR blocks. Example: [\"10.0.0.0/16\"]"
  type        = list(string)
  default     = ["10.0.0.0/16"]

  validation {
    condition     = length(var.vnet_address_space) >= 1
    error_message = "At least one address space CIDR must be provided."
  }
}

variable "public_subnet_prefixes" {
  description = "List of CIDR prefixes for public subnets. One per subnet. Example: [\"10.0.1.0/24\", \"10.0.2.0/24\"]"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_prefixes" {
  description = "List of CIDR prefixes for private subnets. One per subnet. Example: [\"10.0.10.0/24\", \"10.0.11.0/24\"]"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway for private subnet internet egress. Recommended for prod. Additional cost applies."
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
