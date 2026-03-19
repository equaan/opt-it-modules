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
  description = "Version of this module being used. Injected by the Backstage template."
  type        = string
  default     = "1.0.0"
}

# ─────────────────────────────────────────────────────────────
# IAM CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "create_ec2_role" {
  description = "Whether to create an IAM role for EC2 instances (instance profile). Allows EC2 to call AWS APIs."
  type        = bool
  default     = true
}

variable "ec2_s3_bucket_arns" {
  description = "List of S3 bucket ARNs the EC2 role should have read/write access to. Example: [\"arn:aws:s3:::my-bucket\", \"arn:aws:s3:::my-bucket/*\"]"
  type        = list(string)
  default     = []
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources in this module. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
