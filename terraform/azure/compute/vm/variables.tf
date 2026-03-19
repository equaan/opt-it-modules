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
