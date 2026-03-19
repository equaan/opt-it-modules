#!/bin/bash
# ================================================================
# Opt IT — Azure NSG Module Setup
# Run from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-azure-nsg.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating Azure NSG module"
echo "================================================================"

mkdir -p terraform/azure/networking/nsg/examples/basic

cat > terraform/azure/networking/nsg/versions.tf << 'EOF'
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

cat > terraform/azure/networking/nsg/variables.tf << 'EOF'
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

# ─────────────────────────────────────────────────────────────
# DEPENDENCIES — from resource_group and vnet modules
# ─────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Resource group name. Passed from module.resource_group.resource_group_name"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs to associate the public NSG with. Passed from module.vnet.public_subnet_ids"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs to associate the private NSG with. Passed from module.vnet.private_subnet_ids"
  type        = list(string)
  default     = []
}

# ─────────────────────────────────────────────────────────────
# NSG CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "allowed_ssh_source_prefixes" {
  description = "List of IP ranges allowed SSH (port 22) access to VMs. Leave empty to disable SSH. Example: [\"203.0.113.10/32\"]"
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_ssh_source_prefixes, "*") && !contains(var.allowed_ssh_source_prefixes, "0.0.0.0/0")
    error_message = "SSH access from * or 0.0.0.0/0 is not permitted. Provide specific IP ranges."
  }
}

variable "allowed_http_source_prefixes" {
  description = "List of IP ranges allowed HTTP (port 80) access. Use [\"*\"] for public-facing applications."
  type        = list(string)
  default     = ["*"]
}

variable "allowed_https_source_prefixes" {
  description = "List of IP ranges allowed HTTPS (port 443) access. Use [\"*\"] for public-facing applications."
  type        = list(string)
  default     = ["*"]
}

variable "db_port" {
  description = "Port the database listens on. PostgreSQL: 5432, MySQL: 3306, MSSQL: 1433."
  type        = number
  default     = 5432

  validation {
    condition     = contains([1433, 3306, 5432], var.db_port)
    error_message = "db_port must be 1433 (MSSQL), 3306 (MySQL), or 5432 (PostgreSQL)."
  }
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/azure/networking/nsg/main.tf << 'EOF'
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

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-azure-nsg"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# PUBLIC NSG
# Applied to public subnets
# Allows: HTTP, HTTPS inbound from configured sources
#         SSH inbound from configured IPs only (empty = disabled)
#         All outbound
# ─────────────────────────────────────────────────────────────

resource "azurerm_network_security_group" "public" {
  name                = "${local.name_prefix}-nsg-public"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(local.standard_tags, { Tier = "public" })
}

# HTTP inbound
resource "azurerm_network_security_rule" "public_http" {
  count                       = length(var.allowed_http_source_prefixes) > 0 ? 1 : 0
  name                        = "Allow-HTTP-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = var.allowed_http_source_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# HTTPS inbound
resource "azurerm_network_security_rule" "public_https" {
  count                       = length(var.allowed_https_source_prefixes) > 0 ? 1 : 0
  name                        = "Allow-HTTPS-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.allowed_https_source_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# SSH inbound — only if allowed_ssh_source_prefixes is provided
resource "azurerm_network_security_rule" "public_ssh" {
  count                       = length(var.allowed_ssh_source_prefixes) > 0 ? 1 : 0
  name                        = "Allow-SSH-Inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_source_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# Deny all other inbound
resource "azurerm_network_security_rule" "public_deny_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# Associate public NSG with all public subnets
resource "azurerm_subnet_network_security_group_association" "public" {
  count                     = length(var.public_subnet_ids)
  subnet_id                 = var.public_subnet_ids[count.index]
  network_security_group_id = azurerm_network_security_group.public.id
}

# ─────────────────────────────────────────────────────────────
# PRIVATE NSG
# Applied to private subnets
# Allows: DB port inbound from public subnet CIDRs only
#         All outbound (for package installs, API calls etc.)
# ─────────────────────────────────────────────────────────────

resource "azurerm_network_security_group" "private" {
  name                = "${local.name_prefix}-nsg-private"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(local.standard_tags, { Tier = "private" })
}

# DB port inbound from VNet only — databases only reachable internally
resource "azurerm_network_security_rule" "private_db" {
  name                        = "Allow-DB-Inbound-VNet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.db_port)
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
}

# Deny all other inbound to private subnets
resource "azurerm_network_security_rule" "private_deny_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
}

# Associate private NSG with all private subnets
resource "azurerm_subnet_network_security_group_association" "private" {
  count                     = length(var.private_subnet_ids)
  subnet_id                 = var.private_subnet_ids[count.index]
  network_security_group_id = azurerm_network_security_group.private.id
}
EOF

cat > terraform/azure/networking/nsg/outputs.tf << 'EOF'
output "public_nsg_id" {
  description = "ID of the public NSG. Pass to VM module if needed."
  value       = azurerm_network_security_group.public.id
}

output "public_nsg_name" {
  description = "Name of the public NSG."
  value       = azurerm_network_security_group.public.name
}

output "private_nsg_id" {
  description = "ID of the private NSG."
  value       = azurerm_network_security_group.private.id
}

output "private_nsg_name" {
  description = "Name of the private NSG."
  value       = azurerm_network_security_group.private.name
}
EOF

cat > terraform/azure/networking/nsg/CHANGELOG.md << 'EOF'
# Changelog — terraform-azure-nsg

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Public NSG — HTTP (80), HTTPS (443), optional SSH inbound, deny all other inbound
- Private NSG — DB port inbound from VNet only, deny all other inbound
- SSH blocked from * and 0.0.0.0/0 by validation rule
- NSGs automatically associated with all public and private subnets
- Tier tag (public / private) on each NSG
- Standard Opt IT tagging on all resources
- Outputs: public_nsg_id, public_nsg_name, private_nsg_id, private_nsg_name
EOF

cat > terraform/azure/networking/nsg/README.md << 'EOF'
# terraform-azure-nsg

Provisions Network Security Groups for public and private subnets and associates them automatically.

In Azure, NSGs are attached to subnets — every resource in the subnet inherits the rules. This is different from AWS where security groups are attached to individual instances.

Depends on `terraform-azure-resource-group` and `terraform-azure-vnet`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_network_security_group` (public) | HTTP/HTTPS/optional SSH inbound, deny all else |
| `azurerm_network_security_group` (private) | DB port from VNet only, deny all else |
| `azurerm_network_security_rule` (x5) | Individual rules per NSG |
| `azurerm_subnet_network_security_group_association` | Associates NSGs with subnets |

---

## Usage

```hcl
module "nsg" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/networking/nsg?ref=terraform-azure-nsg-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  public_subnet_ids   = module.vnet.public_subnet_ids
  private_subnet_ids  = module.vnet.private_subnet_ids

  allowed_ssh_source_prefixes = ["203.0.113.10/32"]
  db_port                     = 5432
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
| `public_subnet_ids` | Public subnet IDs from vnet module | `list(string)` | `[]` | ❌ |
| `private_subnet_ids` | Private subnet IDs from vnet module | `list(string)` | `[]` | ❌ |
| `allowed_ssh_source_prefixes` | IPs allowed SSH — empty = disabled | `list(string)` | `[]` | ❌ |
| `allowed_http_source_prefixes` | IPs allowed HTTP | `list(string)` | `["*"]` | ❌ |
| `allowed_https_source_prefixes` | IPs allowed HTTPS | `list(string)` | `["*"]` | ❌ |
| `db_port` | Database port: 1433, 3306, or 5432 | `number` | `5432` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `public_nsg_id` | Public NSG ID |
| `public_nsg_name` | Public NSG name |
| `private_nsg_id` | Private NSG ID |
| `private_nsg_name` | Private NSG name |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| Security Group (attached to instance) | NSG (attached to subnet) |
| Inbound/Outbound rules | Inbound/Outbound security rules with priority numbers |
| Implicit deny | Explicit deny rule at priority 4096 |

---

## Security Notes

- SSH from `*` or `0.0.0.0/0` is blocked by a validation rule
- Private subnets only allow DB traffic from within the VNet
- All other inbound is explicitly denied at priority 4096
- NSGs are automatically associated with subnets — no manual wiring needed

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-nsg-v1.0.0`
EOF

cat > terraform/azure/networking/nsg/examples/basic/main.tf << 'EOF'
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

module "vnet" {
  source              = "../../vnet"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
}

module "nsg" {
  source              = "../../"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  public_subnet_ids   = module.vnet.public_subnet_ids
  private_subnet_ids  = module.vnet.private_subnet_ids
  db_port             = 5432
}

output "public_nsg_id"  { value = module.nsg.public_nsg_id }
output "private_nsg_id" { value = module.nsg.private_nsg_id }
EOF

echo ""
echo "================================================================"
echo "  Committing and tagging..."
echo "================================================================"

git add terraform/azure/networking/nsg/
git commit -m "feat(azure): add terraform-azure-nsg v1.0.0"
git tag terraform-azure-nsg-v1.0.0
git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ Azure NSG module pushed and tagged!"
echo "  Tag: terraform-azure-nsg-v1.0.0"
echo "================================================================"