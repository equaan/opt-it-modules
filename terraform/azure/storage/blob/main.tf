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
