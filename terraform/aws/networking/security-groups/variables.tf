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

# ─────────────────────────────────────────────────────────────
# VPC DEPENDENCY
# ─────────────────────────────────────────────────────────────

variable "vpc_id" {
  description = "ID of the VPC to create security groups in. Passed from module.vpc.vpc_id"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC. Used to allow internal traffic between resources. Passed from module.vpc.vpc_cidr"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# SECURITY GROUP CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "allowed_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into EC2 instances. Restrict this to your office IP or VPN range. Example: [\"203.0.113.0/32\"]"
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_ssh_cidrs, "0.0.0.0/0")
    error_message = "SSH access from 0.0.0.0/0 (the entire internet) is not allowed. Provide specific IP ranges."
  }
}

variable "allowed_http_cidrs" {
  description = "List of CIDR blocks allowed HTTP (port 80) access to the web/app tier. Use [\"0.0.0.0/0\"] for public-facing applications."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_cidrs" {
  description = "List of CIDR blocks allowed HTTPS (port 443) access to the web/app tier. Use [\"0.0.0.0/0\"] for public-facing applications."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "rds_port" {
  description = "Port the RDS instance listens on. MySQL: 3306, PostgreSQL: 5432."
  type        = number
  default     = 5432

  validation {
    condition     = contains([3306, 5432], var.rds_port)
    error_message = "rds_port must be 3306 (MySQL) or 5432 (PostgreSQL)."
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources in this module. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
