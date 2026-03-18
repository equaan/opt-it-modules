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
  description = "Version of this module being used. Injected by the Backstage template. Example: 1.0.0"
  type        = string
  default     = "1.0.0"
}

variable "aws_region" {
  description = "AWS region where the VPC will be created. Example: us-east-1"
  type        = string
  default     = "us-east-1"
}

# ─────────────────────────────────────────────────────────────
# VPC CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a valid IPv4 CIDR. Example: 10.0.0.0/16"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block. Example: 10.0.0.0/16"
  }
}

variable "enable_dns_hostnames" {
  description = "Whether to enable DNS hostnames in the VPC. Required for EKS and RDS. Recommended: true."
  type        = bool
  default     = true
}

variable "enable_dns_support" {
  description = "Whether to enable DNS support in the VPC. Required for Route53 and service discovery. Recommended: true."
  type        = bool
  default     = true
}

variable "enable_nat_gateway" {
  description = "Whether to provision a NAT Gateway for private subnet internet access. Note: NAT Gateways have an hourly cost."
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources in this module. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
