#!/bin/bash
# ================================================================
# Opt IT — Azure VM Module Setup
# Run from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-azure-vm.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating Azure VM module"
echo "================================================================"

mkdir -p terraform/azure/compute/vm/examples/basic

cat > terraform/azure/compute/vm/versions.tf << 'EOF'
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

cat > terraform/azure/compute/vm/variables.tf << 'EOF'
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
# DEPENDENCIES — from resource_group, vnet, nsg modules
# ─────────────────────────────────────────────────────────────

variable "resource_group_name" {
  description = "Resource group name. Passed from module.resource_group.resource_group_name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to place the VM in. Use a private subnet. Passed from module.vnet.private_subnet_ids[0]"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# VM CONFIGURATION
# ─────────────────────────────────────────────────────────────

variable "vm_size" {
  description = "Azure VM size. dev: Standard_B2s, staging: Standard_B2ms, prod: Standard_D2s_v3 or larger."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the VM. Cannot be 'admin', 'administrator', or 'root'."
  type        = string
  default     = "azureuser"

  validation {
    condition     = !contains(["admin", "administrator", "root", "guest"], var.admin_username)
    error_message = "admin_username cannot be admin, administrator, root, or guest — these are reserved by Azure."
  }
}

variable "admin_ssh_public_key" {
  description = "SSH public key for admin access. Paste the contents of your .pub file. Leave empty to disable SSH key auth."
  type        = string
  default     = ""
  sensitive   = true
}

variable "os_disk_size_gb" {
  description = "Size of the OS disk in GB. Minimum 30 GB for Ubuntu."
  type        = number
  default     = 30

  validation {
    condition     = var.os_disk_size_gb >= 30
    error_message = "os_disk_size_gb must be at least 30 GB."
  }
}

variable "os_disk_type" {
  description = "Storage type for the OS disk. Standard_LRS: HDD (dev), Premium_LRS: SSD (prod)."
  type        = string
  default     = "Standard_LRS"

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.os_disk_type)
    error_message = "os_disk_type must be Standard_LRS, StandardSSD_LRS, or Premium_LRS."
  }
}

variable "image_publisher" {
  description = "OS image publisher. Default: Canonical (Ubuntu)."
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "OS image offer."
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "OS image SKU. Default: Ubuntu 22.04 LTS."
  type        = string
  default     = "22_04-lts-gen2"
}

variable "enable_public_ip" {
  description = "Whether to assign a public IP to the VM. Set to false for private VMs — use Azure Bastion or VPN for access."
  type        = bool
  default     = false
}

variable "custom_data" {
  description = "Cloud-init script to run on first boot. Base64-encoded. Leave empty for no custom data."
  type        = string
  default     = ""
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/azure/compute/vm/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# PROVIDER
# ─────────────────────────────────────────────────────────────

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    virtual_machine {
      # Prevent accidental deletion of OS disk when VM is destroyed in prod
      delete_os_disk_on_deletion = var.environment != "prod"
    }
  }
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
      Module        = "terraform-azure-vm"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# PUBLIC IP — optional
# Only created when enable_public_ip = true
# ─────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "vm" {
  count               = var.enable_public_ip ? 1 : 0
  name                = "${local.name_prefix}-vm-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.standard_tags
}

# ─────────────────────────────────────────────────────────────
# NETWORK INTERFACE CARD
# Required by Azure before creating a VM
# This is what connects the VM to the subnet
# ─────────────────────────────────────────────────────────────

resource "azurerm_network_interface" "this" {
  name                = "${local.name_prefix}-vm-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.standard_tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.vm[0].id : null
  }
}

# ─────────────────────────────────────────────────────────────
# LINUX VIRTUAL MACHINE
# ─────────────────────────────────────────────────────────────

resource "azurerm_linux_virtual_machine" "this" {
  name                = "${local.name_prefix}-vm"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = local.standard_tags

  # NIC attachment
  network_interface_ids = [azurerm_network_interface.this.id]

  # OS disk
  os_disk {
    name                 = "${local.name_prefix}-vm-osdisk"
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb

    # Always encrypt OS disk
    # Uses platform-managed keys by default
  }

  # OS image
  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = "latest"
  }

  # SSH key auth — used when admin_ssh_public_key is provided
  dynamic "admin_ssh_key" {
    for_each = var.admin_ssh_public_key != "" ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.admin_ssh_public_key
    }
  }

  # Disable password auth when SSH key is provided
  disable_password_authentication = var.admin_ssh_public_key != "" ? true : false

  # Cloud-init script
  custom_data = var.custom_data != "" ? base64encode(var.custom_data) : null

  # Enable Azure-managed boot diagnostics
  boot_diagnostics {}

  lifecycle {
    # Ignore changes to the image version — prevents replacement on minor updates
    ignore_changes = [source_image_reference]
  }
}
EOF

cat > terraform/azure/compute/vm/outputs.tf << 'EOF'
output "vm_id" {
  description = "The ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "The name of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Private IP address of the VM."
  value       = azurerm_network_interface.this.private_ip_address
}

output "public_ip_address" {
  description = "Public IP address of the VM. Empty string if enable_public_ip = false."
  value       = var.enable_public_ip ? azurerm_public_ip.vm[0].ip_address : ""
}

output "nic_id" {
  description = "Network Interface Card ID."
  value       = azurerm_network_interface.this.id
}

output "admin_username" {
  description = "Admin username for SSH access."
  value       = azurerm_linux_virtual_machine.this.admin_username
}
EOF

cat > terraform/azure/compute/vm/CHANGELOG.md << 'EOF'
# Changelog — terraform-azure-vm

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Linux VM (Ubuntu 22.04 LTS default) with configurable size and OS disk
- Network Interface Card (NIC) connected to specified subnet
- Optional static public IP
- SSH key authentication support — password auth disabled when SSH key provided
- OS disk encryption via platform-managed keys (always enabled)
- Boot diagnostics enabled automatically
- delete_os_disk_on_deletion = false for prod environments
- Cloud-init custom data support
- image version ignored in lifecycle to prevent unwanted VM replacement
- Standard Opt IT tagging on all resources
- Outputs: vm_id, vm_name, private_ip_address, public_ip_address, nic_id, admin_username
EOF

cat > terraform/azure/compute/vm/README.md << 'EOF'
# terraform-azure-vm

Provisions an Azure Linux Virtual Machine with NIC, optional public IP, SSH key auth, and encrypted OS disk.

Depends on `terraform-azure-resource-group` and `terraform-azure-vnet`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_network_interface` | NIC connecting VM to subnet |
| `azurerm_public_ip` | Optional static public IP |
| `azurerm_linux_virtual_machine` | The VM with encrypted OS disk |

---

## Usage

```hcl
module "vm" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/compute/vm?ref=terraform-azure-vm-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  subnet_id           = module.vnet.private_subnet_ids[0]

  vm_size              = "Standard_D2s_v3"
  admin_username       = "azureuser"
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
  os_disk_type         = "Premium_LRS"
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
| `subnet_id` | Subnet ID from vnet module | `string` | — | ✅ |
| `vm_size` | Azure VM size | `string` | `Standard_B2s` | ❌ |
| `admin_username` | VM admin username | `string` | `azureuser` | ❌ |
| `admin_ssh_public_key` | SSH public key content | `string` | `""` | ❌ |
| `os_disk_size_gb` | OS disk size in GB | `number` | `30` | ❌ |
| `os_disk_type` | OS disk storage type | `string` | `Standard_LRS` | ❌ |
| `enable_public_ip` | Assign public IP to VM | `bool` | `false` | ❌ |
| `custom_data` | Cloud-init script | `string` | `""` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `vm_id` | VM resource ID |
| `vm_name` | VM name |
| `private_ip_address` | Private IP |
| `public_ip_address` | Public IP (empty if disabled) |
| `nic_id` | Network Interface Card ID |
| `admin_username` | Admin username |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| EC2 instance | Linux Virtual Machine |
| Security Group attachment | NSG on subnet (handled by nsg module) |
| No equivalent | Network Interface Card (required in Azure) |
| Key Pair | admin_ssh_key block |
| User Data | custom_data (cloud-init) |

---

## Recommended VM Sizes By Environment

| Environment | VM Size | vCPUs | RAM |
|---|---|---|---|
| dev | `Standard_B2s` | 2 | 4 GB |
| staging | `Standard_B2ms` | 2 | 8 GB |
| prod | `Standard_D2s_v3` | 2 | 8 GB (SSD) |
| prod (heavy) | `Standard_D4s_v3` | 4 | 16 GB (SSD) |

---

## Notes

- OS disk is always encrypted with platform-managed keys
- `delete_os_disk_on_deletion = false` is automatically set for prod
- Password authentication is disabled when SSH key is provided
- Boot diagnostics are always enabled
- Image version is ignored in lifecycle to prevent VM replacement on minor updates

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-vm-v1.0.0`
EOF

cat > terraform/azure/compute/vm/examples/basic/main.tf << 'EOF'
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
  source              = "../../../networking/vnet"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
}

module "vm" {
  source              = "../../"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  subnet_id           = module.vnet.private_subnet_ids[0]
  vm_size             = "Standard_B2s"
  admin_username      = "azureuser"
}

output "vm_name"            { value = module.vm.vm_name }
output "private_ip_address" { value = module.vm.private_ip_address }
EOF

echo ""
echo "================================================================"
echo "  Committing and tagging..."
echo "================================================================"

git add terraform/azure/compute/
git commit -m "feat(azure): add terraform-azure-vm v1.0.0"
git tag terraform-azure-vm-v1.0.0
git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ Azure VM module pushed and tagged!"
echo "  Tag: terraform-azure-vm-v1.0.0"
echo "================================================================"