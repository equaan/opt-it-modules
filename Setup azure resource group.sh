#!/bin/bash
# ================================================================
# Opt IT — Azure Resource Group Module Setup
# Run from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-azure-resource-group.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating Azure Resource Group module"
echo "================================================================"

mkdir -p terraform/azure/base/resource-group/examples/basic

cat > terraform/azure/base/resource-group/versions.tf << 'EOF'
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

cat > terraform/azure/base/resource-group/variables.tf << 'EOF'
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
  description = "Azure region where resources will be created. Example: eastus, westeurope, southeastasia"
  type        = string

  validation {
    condition     = length(var.location) > 0
    error_message = "location must not be empty. Example: eastus, westeurope, southeastasia"
  }
}

variable "subscription_id" {
  description = "Azure Subscription ID where resources will be deployed. Found in Azure Portal under Subscriptions."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a valid UUID."
  }
}

# ─────────────────────────────────────────────────────────────
# RESOURCE GROUP CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "resource_group_suffix" {
  description = "Optional suffix for the resource group name. Default creates: {client_name}-{environment}-rg"
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/azure/base/resource-group/main.tf << 'EOF'
provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

locals {
  name_prefix         = "${var.client_name}-${var.environment}"
  resource_group_name = var.resource_group_suffix != "" ? "${local.name_prefix}-${var.resource_group_suffix}-rg" : "${local.name_prefix}-rg"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-azure-resource-group"
      Location      = var.location
    },
    var.additional_tags
  )
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.standard_tags
}
EOF

cat > terraform/azure/base/resource-group/outputs.tf << 'EOF'
output "resource_group_name" {
  description = "Resource group name — pass to every other Azure module."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Full resource ID of the resource group."
  value       = azurerm_resource_group.this.id
}

output "location" {
  description = "Azure region — pass to every other Azure module."
  value       = azurerm_resource_group.this.location
}

output "name_prefix" {
  description = "Naming prefix used across all resources."
  value       = local.name_prefix
}

output "standard_tags" {
  description = "Standard tags applied to all resources."
  value       = local.standard_tags
}
EOF

cat > terraform/azure/base/resource-group/CHANGELOG.md << 'EOF'
# Changelog — terraform-azure-resource-group

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Resource Group with configurable location and optional name suffix
- Standard Opt IT tagging on all resources
- Input validation for client_name, environment, subscription_id
- Outputs: resource_group_name, resource_group_id, location, name_prefix, standard_tags
- Provider configuration with explicit subscription_id
EOF

cat > terraform/azure/base/resource-group/README.md << 'EOF'
# terraform-azure-resource-group

Provisions an Azure Resource Group — the mandatory container for all Azure resources.

This is always the first module to run in any Azure deployment. Pass its outputs to every other Azure module.

## Usage

```hcl
module "resource_group" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/base/resource-group?ref=terraform-azure-resource-group-v1.0.0"

  client_name     = "acme-corp"
  environment     = "prod"
  location        = "eastus"
  subscription_id = var.subscription_id
}
```

## Inputs

| Name | Description | Type | Required |
|---|---|---|---|
| `client_name` | Client name | `string` | ✅ |
| `environment` | dev / staging / prod | `string` | ✅ |
| `location` | Azure region | `string` | ✅ |
| `subscription_id` | Azure Subscription ID | `string` | ✅ |
| `module_version` | Module version | `string` | ❌ |
| `resource_group_suffix` | Optional name suffix | `string` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | ❌ |

## Outputs

| Name | Description |
|---|---|
| `resource_group_name` | Pass to every other Azure module |
| `resource_group_id` | Full resource ID |
| `location` | Pass to every other Azure module |
| `name_prefix` | Naming prefix |
| `standard_tags` | Standard tags |

## Authentication

```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

## Module Version

`terraform-azure-resource-group-v1.0.0`
EOF

cat > terraform/azure/base/resource-group/examples/basic/main.tf << 'EOF'
variable "subscription_id" {
  type      = string
  sensitive = true
}

module "resource_group" {
  source          = "../../"
  client_name     = "example-client"
  environment     = "dev"
  location        = "eastus"
  subscription_id = var.subscription_id
}

output "resource_group_name" { value = module.resource_group.resource_group_name }
output "location"            { value = module.resource_group.location }
EOF

echo ""
echo "================================================================"
echo "  Committing and tagging..."
echo "================================================================"

git add terraform/azure/
git commit -m "feat(azure): add terraform-azure-resource-group v1.0.0"
git tag terraform-azure-resource-group-v1.0.0
git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ Azure Resource Group module pushed and tagged!"
echo "  Tag: terraform-azure-resource-group-v1.0.0"
echo "================================================================"