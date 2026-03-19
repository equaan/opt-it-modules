#!/bin/bash
# ================================================================
# Opt IT — Remaining AWS Modules Setup Script
# Run this from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-modules.sh
# ================================================================

set -e  # exit on any error

echo "================================================================"
echo "  Opt IT — Creating remaining AWS modules"
echo "================================================================"

# ────────────────────────────────────────────────────────────────
# MODULE 4 — EC2
# ────────────────────────────────────────────────────────────────

mkdir -p terraform/aws/compute/ec2/examples/basic

cat > terraform/aws/compute/ec2/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/aws/compute/ec2/variables.tf << 'EOF'
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
EOF

cat > terraform/aws/compute/ec2/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-ec2"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# AMI — Latest Amazon Linux 2023
# Only used when ami_id is not explicitly provided
# ─────────────────────────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  resolved_ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id
}

# ─────────────────────────────────────────────────────────────
# EC2 INSTANCE
# ─────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami                    = local.resolved_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name != "" ? var.key_name : null
  monitoring             = var.enable_detailed_monitoring
  user_data_base64       = var.user_data != "" ? base64encode(var.user_data) : null

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true  # always encrypt at rest
    delete_on_termination = true

    tags = merge(local.standard_tags, {
      Name = "${local.name_prefix}-ec2-root-volume"
    })
  }

  # Prevent accidental termination in production
  disable_api_termination = var.environment == "prod" ? true : false

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-ec2"
  })

  lifecycle {
    # AMI ID changes frequently — ignore to prevent unwanted replacement
    ignore_changes = [ami]
  }
}
EOF

cat > terraform/aws/compute/ec2/outputs.tf << 'EOF'
output "instance_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.this.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance. Empty if instance is in a private subnet."
  value       = aws_instance.this.public_ip
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "instance_type" {
  description = "Instance type used."
  value       = aws_instance.this.instance_type
}

output "ami_id" {
  description = "AMI ID used for the instance."
  value       = aws_instance.this.ami
}
EOF

cat > terraform/aws/compute/ec2/CHANGELOG.md << 'EOF'
# Changelog — terraform-aws-ec2

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- EC2 instance with configurable instance type, subnet, and security groups
- Auto-resolves latest Amazon Linux 2023 AMI when ami_id not provided
- Root EBS volume with encryption enforced, configurable size and type (default: gp3)
- API termination protection enabled automatically for prod environments
- Detailed CloudWatch monitoring toggle
- User data support
- Standard Opt IT tagging on all resources
- AMI ID ignored in lifecycle to prevent unwanted instance replacement
EOF

cat > terraform/aws/compute/ec2/README.md << 'EOF'
# terraform-aws-ec2

Provisions a single EC2 instance with encrypted EBS volume, configurable instance type, and production safeguards.

Depends on `terraform-aws-subnets` and `terraform-aws-security-groups`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_instance` | EC2 instance with encrypted root volume |
| `data.aws_ami` | Auto-resolves latest Amazon Linux 2023 (if ami_id not set) |

---

## Usage

```hcl
module "ec2" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/compute/ec2?ref=terraform-aws-ec2-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"
  aws_region  = "us-east-1"

  subnet_id          = module.subnets.private_subnet_ids[0]
  security_group_ids = [module.security_groups.web_security_group_id]

  instance_type    = "t3.medium"
  root_volume_size = 30
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `subnet_id` | Subnet ID from subnets module | `string` | — | ✅ |
| `security_group_ids` | Security group IDs | `list(string)` | — | ✅ |
| `instance_type` | EC2 instance type | `string` | `t3.micro` | ❌ |
| `ami_id` | AMI ID — empty = latest Amazon Linux 2023 | `string` | `""` | ❌ |
| `key_name` | EC2 key pair name for SSH | `string` | `""` | ❌ |
| `root_volume_size` | Root volume size in GB | `number` | `20` | ❌ |
| `root_volume_type` | Root volume type | `string` | `gp3` | ❌ |
| `enable_detailed_monitoring` | CloudWatch detailed monitoring | `bool` | `false` | ❌ |
| `user_data` | User data script | `string` | `""` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `instance_id` | EC2 instance ID |
| `instance_private_ip` | Private IP |
| `instance_public_ip` | Public IP (empty if private subnet) |
| `instance_arn` | Instance ARN |
| `instance_type` | Instance type used |
| `ami_id` | AMI ID used |

---

## Notes

- Root EBS volume is always encrypted — cannot be disabled
- API termination protection is automatically enabled for `prod` environments
- AMI ID is ignored in lifecycle to prevent unwanted instance replacement on AMI updates

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-ec2-v1.0.0`
EOF

cat > terraform/aws/compute/ec2/examples/basic/main.tf << 'EOF'
module "vpc" {
  source      = "../../../networking/vpc"
  client_name = "example-client"
  environment = "dev"
}

module "subnets" {
  source              = "../../../networking/subnets"
  client_name         = "example-client"
  environment         = "dev"
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr
  internet_gateway_id = module.vpc.internet_gateway_id
}

module "security_groups" {
  source      = "../../../networking/security-groups"
  client_name = "example-client"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
}

module "ec2" {
  source             = "../../"
  client_name        = "example-client"
  environment        = "dev"
  subnet_id          = module.subnets.private_subnet_ids[0]
  security_group_ids = [module.security_groups.web_security_group_id]
  instance_type      = "t3.micro"
}

output "instance_id" { value = module.ec2.instance_id }
EOF

echo "✅ EC2 module created"

# ────────────────────────────────────────────────────────────────
# MODULE 5 — S3
# ────────────────────────────────────────────────────────────────

mkdir -p terraform/aws/storage/s3/examples/basic

cat > terraform/aws/storage/s3/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/aws/storage/s3/variables.tf << 'EOF'
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
# S3 CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "bucket_suffix" {
  description = "Optional suffix appended to the bucket name for uniqueness. Example: assets, backups, uploads"
  type        = string
  default     = "storage"
}

variable "enable_versioning" {
  description = "Whether to enable S3 versioning. Recommended for prod. Allows recovery of deleted or overwritten objects."
  type        = bool
  default     = false
}

variable "enable_lifecycle_rules" {
  description = "Whether to enable lifecycle rules to transition old versions to cheaper storage and expire them."
  type        = bool
  default     = false
}

variable "noncurrent_version_transition_days" {
  description = "Days after which noncurrent versions are transitioned to STANDARD_IA. Only applies if lifecycle rules are enabled."
  type        = number
  default     = 30
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which noncurrent versions are permanently deleted. Only applies if lifecycle rules are enabled."
  type        = number
  default     = 90
}

variable "force_destroy" {
  description = "Whether to allow the bucket to be destroyed even if it contains objects. Set to false for prod."
  type        = bool
  default     = false
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources in this module. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/aws/storage/s3/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"
  bucket_name = "${var.client_name}-${var.environment}-${var.bucket_suffix}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-s3"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# S3 BUCKET
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(local.standard_tags, {
    Name = local.bucket_name
  })
}

# ─────────────────────────────────────────────────────────────
# BLOCK ALL PUBLIC ACCESS — enforced on every bucket
# Override only via explicit bucket policy if needed
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────
# SERVER SIDE ENCRYPTION — enforced on every bucket
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ─────────────────────────────────────────────────────────────
# VERSIONING — optional, recommended for prod
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ─────────────────────────────────────────────────────────────
# LIFECYCLE RULES — optional, manages old versions automatically
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "noncurrent-version-management"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
EOF

cat > terraform/aws/storage/s3/outputs.tf << 'EOF'
output "bucket_id" {
  description = "The name of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket. Use in IAM policies to grant access."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "The bucket domain name. Use for static website or CloudFront origin."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket regional domain name."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}
EOF

cat > terraform/aws/storage/s3/CHANGELOG.md << 'EOF'
# Changelog — terraform-aws-s3

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- S3 bucket with configurable name suffix
- Public access block enforced on all buckets — cannot be disabled
- Server-side encryption (AES256) enforced on all buckets — cannot be disabled
- Optional versioning
- Optional lifecycle rules for noncurrent version management
- force_destroy toggle — defaults to false for safety
- Standard Opt IT tagging
EOF

cat > terraform/aws/storage/s3/README.md << 'EOF'
# terraform-aws-s3

Provisions a secure S3 bucket with public access blocked and encryption enforced by default.

No VPC dependency — S3 is a global AWS service.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_s3_bucket` | The S3 bucket |
| `aws_s3_bucket_public_access_block` | Blocks all public access — always enabled |
| `aws_s3_bucket_server_side_encryption_configuration` | AES256 encryption — always enabled |
| `aws_s3_bucket_versioning` | Optional versioning |
| `aws_s3_bucket_lifecycle_configuration` | Optional lifecycle rules for old versions |

---

## Usage

```hcl
module "s3" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/storage/s3?ref=terraform-aws-s3-v1.0.0"

  client_name   = "acme-corp"
  environment   = "prod"
  bucket_suffix = "uploads"

  enable_versioning      = true
  enable_lifecycle_rules = true
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `bucket_suffix` | Suffix for bucket name | `string` | `storage` | ❌ |
| `enable_versioning` | Enable versioning | `bool` | `false` | ❌ |
| `enable_lifecycle_rules` | Enable lifecycle rules | `bool` | `false` | ❌ |
| `noncurrent_version_transition_days` | Days to transition old versions to STANDARD_IA | `number` | `30` | ❌ |
| `noncurrent_version_expiration_days` | Days to expire old versions | `number` | `90` | ❌ |
| `force_destroy` | Allow destroy with objects — false for prod | `bool` | `false` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | Bucket name |
| `bucket_arn` | Bucket ARN — use in IAM policies |
| `bucket_domain_name` | Bucket domain name |
| `bucket_regional_domain_name` | Regional domain name |

---

## Notes

- Public access block and encryption are always enforced and cannot be disabled
- Set `force_destroy = false` for prod to prevent accidental data loss
- Bucket name format: `{client_name}-{environment}-{bucket_suffix}`

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-s3-v1.0.0`
EOF

cat > terraform/aws/storage/s3/examples/basic/main.tf << 'EOF'
module "s3" {
  source        = "../../"
  client_name   = "example-client"
  environment   = "dev"
  bucket_suffix = "uploads"
}

output "bucket_id"  { value = module.s3.bucket_id }
output "bucket_arn" { value = module.s3.bucket_arn }
EOF

echo "✅ S3 module created"

# ────────────────────────────────────────────────────────────────
# MODULE 6 — RDS
# ────────────────────────────────────────────────────────────────

mkdir -p terraform/aws/database/rds/examples/basic

cat > terraform/aws/database/rds/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/aws/database/rds/variables.tf << 'EOF'
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
# SUBNET + SECURITY GROUP DEPENDENCIES
# ─────────────────────────────────────────────────────────────

variable "subnet_ids" {
  description = "List of private subnet IDs for the RDS subnet group. Minimum 2 required for Multi-AZ. Passed from module.subnets.private_subnet_ids"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs required for RDS subnet group."
  }
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the RDS instance. Passed from module.security_groups.database_security_group_id"
  type        = list(string)
}

# ─────────────────────────────────────────────────────────────
# RDS CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "engine" {
  description = "Database engine. Supported: mysql, postgres"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["mysql", "postgres"], var.engine)
    error_message = "engine must be one of: mysql, postgres."
  }
}

variable "engine_version" {
  description = "Database engine version. mysql: 8.0, postgres: 15.4"
  type        = string
  default     = "15.4"
}

variable "instance_class" {
  description = "RDS instance class. dev: db.t3.micro, staging: db.t3.small, prod: db.t3.medium or larger."
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Initial allocated storage in GB."
  type        = number
  default     = 20

  validation {
    condition     = var.allocated_storage >= 20
    error_message = "allocated_storage must be at least 20 GB."
  }
}

variable "max_allocated_storage" {
  description = "Maximum storage in GB for autoscaling. Set to 0 to disable autoscaling."
  type        = number
  default     = 100
}

variable "database_name" {
  description = "Name of the initial database to create."
  type        = string
  default     = "appdb"
}

variable "master_username" {
  description = "Master username for the database."
  type        = string
  default     = "dbadmin"
}

variable "master_password" {
  description = "Master password for the database. Must be at least 8 characters. Store this in AWS Secrets Manager — never in git."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.master_password) >= 8
    error_message = "master_password must be at least 8 characters."
  }
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ deployment for high availability. Recommended for prod. Additional cost applies."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups. 0 disables backups. Minimum 7 recommended for prod."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 0 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 0 and 35."
  }
}

variable "deletion_protection" {
  description = "Whether to enable deletion protection. Automatically set to true for prod."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Whether to skip the final snapshot on deletion. Set to false for prod."
  type        = bool
  default     = true
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources in this module. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/aws/database/rds/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-rds"
    },
    var.additional_tags
  )

  # Prod environments automatically get deletion protection and final snapshot
  is_prod             = var.environment == "prod"
  deletion_protection = local.is_prod ? true : var.deletion_protection
  skip_final_snapshot = local.is_prod ? false : var.skip_final_snapshot
}

# ─────────────────────────────────────────────────────────────
# RDS SUBNET GROUP
# RDS requires a subnet group spanning at least 2 AZs
# ─────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-rds-subnet-group"
  description = "RDS subnet group for ${var.client_name} ${var.environment}"
  subnet_ids  = var.subnet_ids

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-rds-subnet-group"
  })
}

# ─────────────────────────────────────────────────────────────
# RDS INSTANCE
# ─────────────────────────────────────────────────────────────

resource "aws_db_instance" "this" {
  identifier = "${local.name_prefix}-rds"

  # Engine
  engine         = var.engine
  engine_version = var.engine_version

  # Sizing
  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  # Database
  db_name  = var.database_name
  username = var.master_username
  password = var.master_password

  # Network
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids
  publicly_accessible    = false  # never expose RDS to the internet

  # High availability
  multi_az = var.multi_az

  # Storage
  storage_type      = "gp3"
  storage_encrypted = true  # always encrypt at rest

  # Backups
  backup_retention_period = var.backup_retention_days
  backup_window           = "03:00-04:00"  # 3-4am UTC
  maintenance_window      = "Mon:04:00-Mon:05:00"

  # Protection
  deletion_protection       = local.deletion_protection
  skip_final_snapshot       = local.skip_final_snapshot
  final_snapshot_identifier = local.skip_final_snapshot ? null : "${local.name_prefix}-rds-final-snapshot"

  # Performance
  performance_insights_enabled = local.is_prod

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-rds"
  })
}
EOF

cat > terraform/aws/database/rds/outputs.tf << 'EOF'
output "db_instance_id" {
  description = "The RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "The connection endpoint of the RDS instance. Format: hostname:port"
  value       = aws_db_instance.this.endpoint
}

output "db_host" {
  description = "The hostname of the RDS instance."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "The port the RDS instance listens on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "db_subnet_group_name" {
  description = "The name of the RDS subnet group."
  value       = aws_db_subnet_group.this.name
}
EOF

cat > terraform/aws/database/rds/CHANGELOG.md << 'EOF'
# Changelog — terraform-aws-rds

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- RDS instance supporting MySQL and PostgreSQL engines
- RDS subnet group requiring minimum 2 subnets across AZs
- Storage encryption enforced — cannot be disabled
- Publicly accessible set to false — cannot be disabled
- Deletion protection and final snapshot automatically enforced for prod environments
- Performance Insights automatically enabled for prod environments
- Storage autoscaling via max_allocated_storage
- Multi-AZ toggle
- Configurable backup retention (default: 7 days)
- Standard Opt IT tagging
EOF

cat > terraform/aws/database/rds/README.md << 'EOF'
# terraform-aws-rds

Provisions an RDS instance (MySQL or PostgreSQL) with encryption, automated backups, and production safeguards.

Depends on `terraform-aws-subnets` and `terraform-aws-security-groups`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_db_subnet_group` | Subnet group spanning private subnets across AZs |
| `aws_db_instance` | The RDS instance |

---

## Usage

```hcl
module "rds" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/database/rds?ref=terraform-aws-rds-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"

  subnet_ids         = module.subnets.private_subnet_ids
  security_group_ids = [module.security_groups.database_security_group_id]

  engine          = "postgres"
  engine_version  = "15.4"
  instance_class  = "db.t3.medium"
  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_password  # from secrets manager

  multi_az              = true
  backup_retention_days = 14
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `subnet_ids` | Private subnet IDs (min 2) | `list(string)` | — | ✅ |
| `security_group_ids` | Security group IDs | `list(string)` | — | ✅ |
| `master_password` | DB master password (sensitive) | `string` | — | ✅ |
| `engine` | mysql or postgres | `string` | `postgres` | ❌ |
| `engine_version` | Engine version | `string` | `15.4` | ❌ |
| `instance_class` | RDS instance class | `string` | `db.t3.micro` | ❌ |
| `allocated_storage` | Initial storage in GB | `number` | `20` | ❌ |
| `max_allocated_storage` | Max storage for autoscaling | `number` | `100` | ❌ |
| `database_name` | Initial database name | `string` | `appdb` | ❌ |
| `master_username` | Master username | `string` | `dbadmin` | ❌ |
| `multi_az` | Enable Multi-AZ | `bool` | `false` | ❌ |
| `backup_retention_days` | Backup retention in days | `number` | `7` | ❌ |
| `deletion_protection` | Enable deletion protection | `bool` | `false` | ❌ |
| `skip_final_snapshot` | Skip final snapshot on delete | `bool` | `true` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `db_instance_id` | RDS instance identifier |
| `db_instance_arn` | RDS instance ARN |
| `db_endpoint` | Connection endpoint (hostname:port) |
| `db_host` | Hostname only |
| `db_port` | Port number |
| `db_name` | Database name |
| `db_subnet_group_name` | Subnet group name |

---

## Notes

- `publicly_accessible` is always false — RDS is never exposed to the internet
- Storage is always encrypted
- For prod: deletion protection and final snapshot are automatically enforced
- Never commit `master_password` to git — use AWS Secrets Manager or Terraform Cloud variables

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-rds-v1.0.0`
EOF

cat > terraform/aws/database/rds/examples/basic/main.tf << 'EOF'
module "vpc" {
  source      = "../../../networking/vpc"
  client_name = "example-client"
  environment = "dev"
}

module "subnets" {
  source              = "../../../networking/subnets"
  client_name         = "example-client"
  environment         = "dev"
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr
  internet_gateway_id = module.vpc.internet_gateway_id
}

module "security_groups" {
  source      = "../../../networking/security-groups"
  client_name = "example-client"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
  rds_port    = 5432
}

module "rds" {
  source             = "../../"
  client_name        = "example-client"
  environment        = "dev"
  subnet_ids         = module.subnets.private_subnet_ids
  security_group_ids = [module.security_groups.database_security_group_id]
  engine             = "postgres"
  master_password    = "changeme123"  # use secrets manager in real usage
}

output "db_endpoint" { value = module.rds.db_endpoint }
EOF

echo "✅ RDS module created"

# ────────────────────────────────────────────────────────────────
# MODULE 7 — IAM BASELINE
# ────────────────────────────────────────────────────────────────

mkdir -p terraform/aws/iam/baseline/examples/basic

cat > terraform/aws/iam/baseline/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/aws/iam/baseline/variables.tf << 'EOF'
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
EOF

cat > terraform/aws/iam/baseline/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-iam-baseline"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# EC2 INSTANCE ROLE
# Allows EC2 instances to call AWS APIs using instance metadata
# Attach to EC2 via instance profile
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2" {
  count = var.create_ec2_role ? 1 : 0

  name        = "${local.name_prefix}-ec2-role"
  description = "IAM role for EC2 instances in ${var.client_name} ${var.environment}. Managed by Opt IT Backstage."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-ec2-role"
  })
}

# SSM Session Manager — allows shell access without SSH keys or bastion hosts
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  count      = var.create_ec2_role ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent — allows EC2 to push logs and metrics
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  count      = var.create_ec2_role ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# S3 access — only created if bucket ARNs are provided
resource "aws_iam_role_policy" "ec2_s3" {
  count = var.create_ec2_role && length(var.ec2_s3_bucket_arns) > 0 ? 1 : 0

  name = "${local.name_prefix}-ec2-s3-policy"
  role = aws_iam_role.ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = var.ec2_s3_bucket_arns
      }
    ]
  })
}

# Instance profile — wraps the role so it can be attached to EC2
resource "aws_iam_instance_profile" "ec2" {
  count = var.create_ec2_role ? 1 : 0

  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2[0].name

  tags = local.standard_tags
}
EOF

cat > terraform/aws/iam/baseline/outputs.tf << 'EOF'
output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role. Empty if create_ec2_role = false."
  value       = var.create_ec2_role ? aws_iam_role.ec2[0].arn : ""
}

output "ec2_role_name" {
  description = "Name of the EC2 IAM role."
  value       = var.create_ec2_role ? aws_iam_role.ec2[0].name : ""
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile. Pass to ec2 module as iam_instance_profile."
  value       = var.create_ec2_role ? aws_iam_instance_profile.ec2[0].name : ""
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile."
  value       = var.create_ec2_role ? aws_iam_instance_profile.ec2[0].arn : ""
}
EOF

cat > terraform/aws/iam/baseline/CHANGELOG.md << 'EOF'
# Changelog — terraform-aws-iam-baseline

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- EC2 IAM role with assume role policy for ec2.amazonaws.com
- SSM Session Manager policy attached — enables shell access without SSH or bastion hosts
- CloudWatch Agent policy attached — enables log and metric publishing
- Optional S3 read/write policy for specified bucket ARNs
- EC2 instance profile wrapping the role
- Standard Opt IT tagging
EOF

cat > terraform/aws/iam/baseline/README.md << 'EOF'
# terraform-aws-iam-baseline

Provisions baseline IAM roles and instance profiles for a client environment.

No VPC dependency — IAM is a global AWS service.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_iam_role` (ec2) | Role for EC2 instances to call AWS APIs |
| `aws_iam_role_policy_attachment` (ssm) | Allows SSM Session Manager shell access |
| `aws_iam_role_policy_attachment` (cloudwatch) | Allows CloudWatch log/metric publishing |
| `aws_iam_role_policy` (s3) | S3 read/write access — only if bucket ARNs provided |
| `aws_iam_instance_profile` | Wraps EC2 role for attachment to instances |

---

## Usage

```hcl
module "iam" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/iam/baseline?ref=terraform-aws-iam-baseline-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"

  create_ec2_role    = true
  ec2_s3_bucket_arns = [
    module.s3.bucket_arn,
    "${module.s3.bucket_arn}/*"
  ]
}

# Then pass the instance profile to the ec2 module:
# iam_instance_profile = module.iam.ec2_instance_profile_name
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `create_ec2_role` | Create EC2 role and instance profile | `bool` | `true` | ❌ |
| `ec2_s3_bucket_arns` | S3 bucket ARNs for EC2 access | `list(string)` | `[]` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `ec2_role_arn` | EC2 IAM role ARN |
| `ec2_role_name` | EC2 IAM role name |
| `ec2_instance_profile_name` | Instance profile name — pass to ec2 module |
| `ec2_instance_profile_arn` | Instance profile ARN |

---

## Notes

- SSM Session Manager is always attached — eliminates the need for SSH keys or bastion hosts
- CloudWatch Agent is always attached — required for log and metric collection
- Never grant `*` permissions — use `ec2_s3_bucket_arns` to explicitly specify which buckets

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-iam-baseline-v1.0.0`
EOF

cat > terraform/aws/iam/baseline/examples/basic/main.tf << 'EOF'
module "s3" {
  source        = "../../../storage/s3"
  client_name   = "example-client"
  environment   = "dev"
  bucket_suffix = "uploads"
}

module "iam" {
  source      = "../../"
  client_name = "example-client"
  environment = "dev"

  ec2_s3_bucket_arns = [
    module.s3.bucket_arn,
    "${module.s3.bucket_arn}/*"
  ]
}

output "ec2_instance_profile_name" { value = module.iam.ec2_instance_profile_name }
EOF

echo "✅ IAM baseline module created"

# ────────────────────────────────────────────────────────────────
# COMMIT AND TAG ALL MODULES
# ────────────────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo "  Committing and tagging all modules..."
echo "================================================================"

git add .
git commit -m "feat: add compute/ec2, storage/s3, database/rds, iam/baseline modules v1.0.0"

git tag terraform-aws-ec2-v1.0.0
git tag terraform-aws-s3-v1.0.0
git tag terraform-aws-rds-v1.0.0
git tag terraform-aws-iam-baseline-v1.0.0

git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ All modules created, committed, and tagged!"
echo ""
echo "  Tags created:"
echo "    terraform-aws-ec2-v1.0.0"
echo "    terraform-aws-s3-v1.0.0"
echo "    terraform-aws-rds-v1.0.0"
echo "    terraform-aws-iam-baseline-v1.0.0"
echo "================================================================"