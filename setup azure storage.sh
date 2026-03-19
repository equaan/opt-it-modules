#!/bin/bash
# ================================================================
# Opt IT — Azure Blob Storage Module Setup
# Run from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-azure-storage.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating Azure Blob Storage module"
echo "================================================================"

mkdir -p terraform/azure/storage/blob/examples/basic

cat > terraform/azure/storage/blob/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}
EOF

cat > terraform/azure/storage/blob/variables.tf << 'EOF'
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

variable "resource_group_name" {
  description = "Resource group name. Passed from module.resource_group.resource_group_name"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# STORAGE CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "storage_suffix" {
  description = "Short suffix for the storage account name. Combined with client and environment. Lowercase alphanumeric only, max 5 chars. Example: data, app, bkp"
  type        = string
  default     = "store"

  validation {
    condition     = can(regex("^[a-z0-9]{1,5}$", var.storage_suffix))
    error_message = "storage_suffix must be lowercase alphanumeric only, max 5 characters."
  }
}

variable "account_replication_type" {
  description = "Storage replication type. LRS: single region (dev), GRS: geo-redundant (prod). Options: LRS, GRS, RAGRS, ZRS."
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.account_replication_type)
    error_message = "account_replication_type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

variable "enable_versioning" {
  description = "Whether to enable blob versioning. Recommended for prod. Allows recovery of deleted or overwritten blobs."
  type        = bool
  default     = false
}

variable "enable_soft_delete" {
  description = "Whether to enable soft delete for blobs. Deleted blobs are retained for retention_days before permanent deletion."
  type        = bool
  default     = true
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain soft-deleted blobs. Only applies if enable_soft_delete = true."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days must be between 1 and 365."
  }
}

variable "container_names" {
  description = "List of blob container names to create inside the storage account. Example: [\"uploads\", \"backups\"]"
  type        = list(string)
  default     = ["default"]
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/azure/storage/blob/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# PROVIDER
# ─────────────────────────────────────────────────────────────

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  # Storage account names must be globally unique, 3-24 chars,
  # lowercase alphanumeric only — no hyphens allowed
  # Format: {client}{env}{suffix} with hyphens stripped
  storage_account_name = substr(
    replace("${var.client_name}${var.environment}${var.storage_suffix}", "-", ""),
    0,
    24
  )

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-azure-blob-storage"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# STORAGE ACCOUNT
# ─────────────────────────────────────────────────────────────

resource "azurerm_storage_account" "this" {
  name                     = local.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = var.account_replication_type
  tags                     = local.standard_tags

  # Always enforce HTTPS — HTTP access is blocked
  enable_https_traffic_only = true

  # Always use TLS 1.2 minimum
  min_tls_version = "TLS1_2"

  # Block all public blob access — containers are private by default
  allow_nested_items_to_be_public = false

  blob_properties {
    # Versioning
    versioning_enabled = var.enable_versioning

    # Soft delete for blobs
    dynamic "delete_retention_policy" {
      for_each = var.enable_soft_delete ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }

    # Soft delete for containers
    dynamic "container_delete_retention_policy" {
      for_each = var.enable_soft_delete ? [1] : []
      content {
        days = var.soft_delete_retention_days
      }
    }
  }
}

# ─────────────────────────────────────────────────────────────
# BLOB CONTAINERS
# One per entry in container_names
# All containers are private — no anonymous public access
# ─────────────────────────────────────────────────────────────

resource "azurerm_storage_container" "this" {
  for_each              = toset(var.container_names)
  name                  = each.value
  storage_account_name  = azurerm_storage_account.this.name
  container_access_type = "private"
}
EOF

cat > terraform/azure/storage/blob/outputs.tf << 'EOF'
output "storage_account_id" {
  description = "The ID of the storage account."
  value       = azurerm_storage_account.this.id
}

output "storage_account_name" {
  description = "The name of the storage account. Used for Azure CLI and SDK access."
  value       = azurerm_storage_account.this.name
}

output "primary_blob_endpoint" {
  description = "The primary blob service endpoint URL."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "primary_access_key" {
  description = "The primary access key for the storage account. Treat as a secret — store in Key Vault."
  value       = azurerm_storage_account.this.primary_access_key
  sensitive   = true
}

output "primary_connection_string" {
  description = "The primary connection string for the storage account. Treat as a secret — store in Key Vault."
  value       = azurerm_storage_account.this.primary_connection_string
  sensitive   = true
}

output "container_names" {
  description = "List of container names created inside the storage account."
  value       = [for c in azurerm_storage_container.this : c.name]
}
EOF

cat > terraform/azure/storage/blob/CHANGELOG.md << 'EOF'
# Changelog — terraform-azure-blob-storage

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Storage Account with configurable replication type
- HTTPS-only access enforced — cannot be disabled
- TLS 1.2 minimum enforced — cannot be disabled
- Public blob access blocked — all containers are private by default
- Optional blob versioning
- Optional soft delete for blobs and containers with configurable retention
- Multiple blob containers via container_names list
- Storage account name auto-generated to meet Azure naming constraints (no hyphens, max 24 chars)
- Outputs: storage_account_id, storage_account_name, primary_blob_endpoint, primary_access_key (sensitive), primary_connection_string (sensitive), container_names
EOF

cat > terraform/azure/storage/blob/README.md << 'EOF'
# terraform-azure-blob-storage

Provisions an Azure Storage Account with private blob containers, HTTPS enforced, and optional versioning and soft delete.

Depends on `terraform-azure-resource-group`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_storage_account` | The storage account with security defaults |
| `azurerm_storage_container` | One per entry in container_names |

---

## Usage

```hcl
module "storage" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/storage/blob?ref=terraform-azure-blob-storage-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name

  storage_suffix           = "data"
  account_replication_type = "GRS"
  enable_versioning        = true
  enable_soft_delete       = true
  container_names          = ["uploads", "backups", "exports"]
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `location` | Azure region | `string` | — | ✅ |
| `subscription_id` | Azure Subscription ID | `string` | — | ✅ |
| `resource_group_name` | Resource group name | `string` | — | ✅ |
| `storage_suffix` | Short suffix (max 5 chars, no hyphens) | `string` | `store` | ❌ |
| `account_replication_type` | LRS / GRS / ZRS etc. | `string` | `LRS` | ❌ |
| `enable_versioning` | Enable blob versioning | `bool` | `false` | ❌ |
| `enable_soft_delete` | Enable soft delete | `bool` | `true` | ❌ |
| `soft_delete_retention_days` | Soft delete retention in days | `number` | `7` | ❌ |
| `container_names` | List of container names to create | `list(string)` | `["default"]` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `storage_account_id` | Storage account resource ID |
| `storage_account_name` | Storage account name |
| `primary_blob_endpoint` | Blob service endpoint URL |
| `primary_access_key` | Primary access key (sensitive) |
| `primary_connection_string` | Primary connection string (sensitive) |
| `container_names` | List of created container names |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| S3 Bucket | Storage Account |
| S3 Prefix / Folder | Blob Container |
| Bucket Policy | Storage Account access keys / RBAC |
| S3 Versioning | Blob Versioning |
| S3 Object expiry | Soft Delete retention |

---

## Storage Account Naming

Azure storage account names must be globally unique, 3-24 characters, lowercase alphanumeric only — no hyphens. This module auto-generates the name:

```
{client_name}{environment}{suffix}  →  hyphens stripped, truncated to 24 chars

Examples:
  acme-corp + prod + data  →  acmecorpproddata
  my-client + staging + bkp  →  myclientstagingbkp
```

---

## Replication Types

| Type | Description | Use case |
|---|---|---|
| `LRS` | Locally redundant — 3 copies in one datacenter | dev |
| `ZRS` | Zone redundant — 3 copies across AZs | staging |
| `GRS` | Geo redundant — copies to secondary region | prod |
| `RAGRS` | Read-access geo redundant — readable from secondary | prod (read-heavy) |

---

## Notes

- HTTPS-only and TLS 1.2 minimum are always enforced
- All containers are private — anonymous public access is blocked
- Store `primary_access_key` and `primary_connection_string` in Azure Key Vault — never in code

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-blob-storage-v1.0.0`
EOF

cat > terraform/azure/storage/blob/examples/basic/main.tf << 'EOF'
variable "subscription_id" {
  type      = string
  sensitive = true
}

module "resource_group" {
  source          = "../../../base/resource-group"
  client_name     = "example-client"
  environment     = "dev"
  location        = "eastus"
  subscription_id = var.subscription_id
}

module "storage" {
  source              = "../../"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  storage_suffix      = "data"
  container_names     = ["uploads", "backups"]
}

output "storage_account_name" { value = module.storage.storage_account_name }
output "primary_blob_endpoint" { value = module.storage.primary_blob_endpoint }
EOF

echo ""
echo "================================================================"
echo "  Committing and tagging..."
echo "================================================================"

git add terraform/azure/storage/
git commit -m "feat(azure): add terraform-azure-blob-storage v1.0.0"
git tag terraform-azure-blob-storage-v1.0.0
git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ Azure Blob Storage module pushed and tagged!"
echo "  Tag: terraform-azure-blob-storage-v1.0.0"
echo "================================================================"