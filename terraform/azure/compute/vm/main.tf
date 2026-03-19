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
