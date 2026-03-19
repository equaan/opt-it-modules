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
      Module        = "terraform-azure-sql-flexible"
    },
    var.additional_tags
  )

  is_prod = var.environment == "prod"
}

# ─────────────────────────────────────────────────────────────
# POSTGRESQL FLEXIBLE SERVER
# Only created when db_engine = "postgres"
# ─────────────────────────────────────────────────────────────

resource "azurerm_postgresql_flexible_server" "this" {
  count = var.db_engine == "postgres" ? 1 : 0

  name                   = "${local.name_prefix}-psql"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.db_version
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  zone                   = "1"
  sku_name               = var.sku_name
  tags                   = local.standard_tags

  storage_mb = var.storage_mb

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  dynamic "high_availability" {
    for_each = var.high_availability_mode != "Disabled" ? [1] : []
    content {
      mode                      = var.high_availability_mode
      standby_availability_zone = var.high_availability_mode == "ZoneRedundant" ? "2" : null
    }
  }

  # Maintenance window — 3am Sunday UTC to minimise impact
  maintenance_window {
    day_of_week  = 0
    start_hour   = 3
    start_minute = 0
  }

  lifecycle {
    # Prevent accidental deletion in prod
    prevent_destroy = false

    # Ignore changes to zone — Azure may move the server
    ignore_changes = [zone]
  }
}

# Initial database on PostgreSQL server
resource "azurerm_postgresql_flexible_server_database" "this" {
  count     = var.db_engine == "postgres" ? 1 : 0
  name      = var.initial_db_name
  server_id = azurerm_postgresql_flexible_server.this[0].id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# ─────────────────────────────────────────────────────────────
# MYSQL FLEXIBLE SERVER
# Only created when db_engine = "mysql"
# ─────────────────────────────────────────────────────────────

resource "azurerm_mysql_flexible_server" "this" {
  count = var.db_engine == "mysql" ? 1 : 0

  name                   = "${local.name_prefix}-mysql"
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.db_version
  delegated_subnet_id    = var.delegated_subnet_id
  private_dns_zone_id    = var.private_dns_zone_id
  administrator_login    = var.admin_username
  administrator_password = var.admin_password
  zone                   = "1"
  sku_name               = var.sku_name
  tags                   = local.standard_tags

  storage {
    size_gb = var.storage_mb / 1024
  }

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  dynamic "high_availability" {
    for_each = var.high_availability_mode != "Disabled" ? [1] : []
    content {
      mode                      = var.high_availability_mode
      standby_availability_zone = var.high_availability_mode == "ZoneRedundant" ? "2" : null
    }
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 3
    start_minute = 0
  }

  lifecycle {
    ignore_changes = [zone]
  }
}

# Initial database on MySQL server
resource "azurerm_mysql_flexible_database" "this" {
  count               = var.db_engine == "mysql" ? 1 : 0
  name                = var.initial_db_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.this[0].name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}
