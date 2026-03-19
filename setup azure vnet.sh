#!/bin/bash
# ================================================================
# Opt IT — Azure VNet Module Setup
# Run from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-azure-vnet.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating Azure VNet module"
echo "================================================================"

mkdir -p terraform/azure/networking/vnet/examples/basic

cat > terraform/azure/networking/vnet/versions.tf << 'EOF'
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

cat > terraform/azure/networking/vnet/variables.tf << 'EOF'
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
EOF

cat > terraform/azure/networking/vnet/main.tf << 'EOF'
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
      Module        = "terraform-azure-vnet"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# VIRTUAL NETWORK
# ─────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "this" {
  name                = "${local.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = local.standard_tags
}

# ─────────────────────────────────────────────────────────────
# PUBLIC SUBNETS
# Internet-facing resources — load balancers, bastion hosts
# ─────────────────────────────────────────────────────────────

resource "azurerm_subnet" "public" {
  count                = length(var.public_subnet_prefixes)
  name                 = "${local.name_prefix}-public-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.public_subnet_prefixes[count.index]]
}

# ─────────────────────────────────────────────────────────────
# PRIVATE SUBNETS
# Internal resources — VMs, databases, app servers
# ─────────────────────────────────────────────────────────────

resource "azurerm_subnet" "private" {
  count                = length(var.private_subnet_prefixes)
  name                 = "${local.name_prefix}-private-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_subnet_prefixes[count.index]]
}

# ─────────────────────────────────────────────────────────────
# NAT GATEWAY — optional
# Allows private subnet resources to reach the internet
# ─────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${local.name_prefix}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.standard_tags
}

resource "azurerm_nat_gateway" "this" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${local.name_prefix}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = local.standard_tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

# Associate NAT Gateway with all private subnets
resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = var.enable_nat_gateway ? length(azurerm_subnet.private) : 0
  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
EOF

cat > terraform/azure/networking/vnet/outputs.tf << 'EOF'
output "vnet_id" {
  description = "The ID of the Virtual Network. Pass to NSG and VM modules."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "The name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "The address space of the VNet."
  value       = azurerm_virtual_network.this.address_space
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = azurerm_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs. Pass to VM and SQL modules."
  value       = azurerm_subnet.private[*].id
}

output "public_subnet_names" {
  description = "List of public subnet names."
  value       = azurerm_subnet.public[*].name
}

output "private_subnet_names" {
  description = "List of private subnet names."
  value       = azurerm_subnet.private[*].name
}

output "nat_gateway_id" {
  description = "NAT Gateway ID. Empty string if enable_nat_gateway = false."
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.this[0].id : ""
}
EOF

cat > terraform/azure/networking/vnet/CHANGELOG.md << 'EOF'
# Changelog — terraform-azure-vnet

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Virtual Network with configurable address space
- Public subnets — configurable count via public_subnet_prefixes list
- Private subnets — configurable count via private_subnet_prefixes list
- Optional NAT Gateway with Public IP for private subnet internet egress
- NAT Gateway associated with all private subnets automatically
- Standard Opt IT tagging on all resources
- Outputs: vnet_id, vnet_name, public_subnet_ids, private_subnet_ids, nat_gateway_id
EOF

cat > terraform/azure/networking/vnet/README.md << 'EOF'
# terraform-azure-vnet

Provisions an Azure Virtual Network with public and private subnets and an optional NAT Gateway.

In Azure, VNet and Subnets are managed together — this module replaces both the `vpc` and `subnets` modules from the AWS stack.

Depends on `terraform-azure-resource-group`. Consumes `resource_group_name` and `location` from its outputs.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_virtual_network` | The VNet |
| `azurerm_subnet` (public) | One per entry in public_subnet_prefixes |
| `azurerm_subnet` (private) | One per entry in private_subnet_prefixes |
| `azurerm_public_ip` | Static public IP for NAT Gateway (if enabled) |
| `azurerm_nat_gateway` | NAT Gateway for private subnet egress (if enabled) |
| `azurerm_nat_gateway_public_ip_association` | Links NAT Gateway to public IP |
| `azurerm_subnet_nat_gateway_association` | Associates NAT Gateway with private subnets |

---

## Usage

```hcl
module "vnet" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/networking/vnet?ref=terraform-azure-vnet-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name

  vnet_address_space      = ["10.0.0.0/16"]
  public_subnet_prefixes  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_prefixes = ["10.0.10.0/24", "10.0.11.0/24"]
  enable_nat_gateway      = true
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `location` | Azure region from resource_group module | `string` | — | ✅ |
| `subscription_id` | Azure Subscription ID | `string` | — | ✅ |
| `resource_group_name` | Resource group name from resource_group module | `string` | — | ✅ |
| `vnet_address_space` | VNet CIDR address space | `list(string)` | `["10.0.0.0/16"]` | ❌ |
| `public_subnet_prefixes` | Public subnet CIDRs | `list(string)` | `["10.0.1.0/24","10.0.2.0/24"]` | ❌ |
| `private_subnet_prefixes` | Private subnet CIDRs | `list(string)` | `["10.0.10.0/24","10.0.11.0/24"]` | ❌ |
| `enable_nat_gateway` | Provision NAT Gateway | `bool` | `false` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `vnet_id` | VNet ID |
| `vnet_name` | VNet name |
| `vnet_address_space` | VNet address space |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs — pass to VM and SQL modules |
| `public_subnet_names` | List of public subnet names |
| `private_subnet_names` | List of private subnet names |
| `nat_gateway_id` | NAT Gateway ID (empty if disabled) |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| VPC | Virtual Network (VNet) |
| Subnet | Subnet (inside VNet) |
| Internet Gateway | Handled automatically by Azure |
| NAT Gateway | NAT Gateway (same concept, different resource) |

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-vnet-v1.0.0`
EOF

cat > terraform/azure/networking/vnet/examples/basic/main.tf << 'EOF'
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
  source              = "../../"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
}

output "vnet_id"            { value = module.vnet.vnet_id }
output "public_subnet_ids"  { value = module.vnet.public_subnet_ids }
output "private_subnet_ids" { value = module.vnet.private_subnet_ids }
EOF

echo ""
echo "================================================================"
echo "  Committing and tagging..."
echo "================================================================"

git add terraform/azure/networking/
git commit -m "feat(azure): add terraform-azure-vnet v1.0.0"
git tag terraform-azure-vnet-v1.0.0
git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ Azure VNet module pushed and tagged!"
echo "  Tag: terraform-azure-vnet-v1.0.0"
echo "================================================================"