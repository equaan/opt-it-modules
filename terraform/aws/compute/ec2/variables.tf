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
  description = "AWS region where the EC2 instance will be created. Example: us-east-1"
  type        = string
  default     = "us-east-1"
}

# ─────────────────────────────────────────────────────────────
# SUBNET + SECURITY GROUP DEPENDENCIES
# ─────────────────────────────────────────────────────────────

variable "subnet_id" {
  description = "ID of the subnet to launch the instance in. Use private subnet for app servers. Passed from module.subnets.private_subnet_ids[0]"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the instance. Passed from module.security_groups.web_security_group_id"
  type        = list(string)
}

# ─────────────────────────────────────────────────────────────
# EC2 CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "instance_type" {
  description = "EC2 instance type. dev: t3.micro, staging: t3.small, prod: t3.medium or larger."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.(nano|micro|small|medium|large|xlarge|2xlarge|4xlarge|8xlarge|16xlarge)$", var.instance_type))
    error_message = "instance_type must be a valid EC2 instance type. Example: t3.micro, t3.medium, m5.large"
  }
}

variable "ami_id" {
  description = "AMI ID to use for the instance. Defaults to latest Amazon Linux 2023. Override with a specific AMI for reproducibility."
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Name of the EC2 key pair for SSH access. Leave empty if SSH is not required."
  type        = string
  default     = ""
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GB."
  }
}

variable "root_volume_type" {
  description = "Type of the root EBS volume. gp3 is recommended for cost and performance."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "root_volume_type must be one of: gp2, gp3, io1, io2."
  }
}

variable "enable_detailed_monitoring" {
  description = "Whether to enable detailed CloudWatch monitoring (1-minute intervals). Additional cost applies."
  type        = bool
  default     = false
}

variable "user_data" {
  description = "User data script to run on instance launch. Base64-encoded. Leave empty for no user data."
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources in this module. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
