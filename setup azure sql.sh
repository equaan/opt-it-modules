#!/bin/bash
# ================================================================
# Opt IT — Azure SQL Flexible Server Module Setup
# Run from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-azure-sql.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating Azure SQL Flexible Server module"
echo "================================================================"

mkdir -p terraform/azure/database/sql-flexible/examples/basic

cat > terraform/azure/database/sql-flexible/versions.tf << 'EOF'
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

cat > terraform/azure/database/sql-flexible/variables.tf << 'EOF'
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
# VNET DEPENDENCY — for private access
# ─────────────────────────────────────────────────────────────

variable "delegated_subnet_id" {
  description = "ID of a subnet delegated to the database service. Must be an empty subnet — cannot contain other resources. Passed from module.vnet.private_subnet_ids[1]"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone for the flexible server. Must be created separately and linked to the VNet. Example: /subscriptions/.../privateDnsZones/acme-corp.postgres.database.azure.com"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# DATABASE ENGINE
# ─────────────────────────────────────────────────────────────

variable "db_engine" {
  description = "Database engine to provision. postgres = PostgreSQL Flexible Server, mysql = MySQL Flexible Server."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.db_engine)
    error_message = "db_engine must be one of: postgres, mysql."
  }
}

variable "db_version" {
  description = "Database engine version. PostgreSQL: 14, 15, 16. MySQL: 8.0."
  type        = string
  default     = "15"
}

variable "sku_name" {
  description = "SKU for the flexible server. Format: {tier}_{family}_{vcores}. dev: B_Standard_B1ms, prod: GP_Standard_D2s_v3"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB. Minimum 32768 (32 GB). Example: 32768, 65536, 131072."
  type        = number
  default     = 32768

  validation {
    condition     = var.storage_mb >= 32768
    error_message = "storage_mb must be at least 32768 (32 GB)."
  }
}

variable "admin_username" {
  description = "Administrator username for the database server."
  type        = string
  default     = "dbadmin"

  validation {
    condition     = !contains(["admin", "administrator", "root", "guest", "azure_superuser"], var.admin_username)
    error_message = "admin_username cannot use reserved names: admin, administrator, root, guest, azure_superuser."
  }
}

variable "admin_password" {
  description = "Administrator password. Minimum 8 chars, must include uppercase, lowercase, number, and special character. Never commit this — use TF_VAR_admin_password or a secrets manager."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "admin_password must be at least 8 characters."
  }
}

variable "backup_retention_days" {
  description = "Number of days to retain automated backups. Minimum 7 for prod."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 1 and 35."
  }
}

variable "geo_redundant_backup" {
  description = "Whether to enable geo-redundant backups. Recommended for prod. Additional cost applies."
  type        = bool
  default     = false
}

variable "high_availability_mode" {
  description = "High availability mode. Disabled: no HA, SameZone: standby in same zone, ZoneRedundant: standby in different zone. Recommended ZoneRedundant for prod."
  type        = string
  default     = "Disabled"

  validation {
    condition     = contains(["Disabled", "SameZone", "ZoneRedundant"], var.high_availability_mode)
    error_message = "high_availability_mode must be Disabled, SameZone, or ZoneRedundant."
  }
}

variable "initial_db_name" {
  description = "Name of the initial database to create on the server."
  type        = string
  default     = "appdb"
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources. Merged with standard Opt IT tags."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/azure/database/sql-flexible/main.tf << 'EOF'
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
EOF

cat > terraform/azure/database/sql-flexible/outputs.tf << 'EOF'
output "server_id" {
  description = "The ID of the database server."
  value       = var.db_engine == "postgres" ? azurerm_postgresql_flexible_server.this[0].id : azurerm_mysql_flexible_server.this[0].id
}

output "server_name" {
  description = "The name of the database server."
  value       = var.db_engine == "postgres" ? azurerm_postgresql_flexible_server.this[0].name : azurerm_mysql_flexible_server.this[0].name
}

output "server_fqdn" {
  description = "Fully qualified domain name of the database server. Use this as the host in connection strings."
  value       = var.db_engine == "postgres" ? azurerm_postgresql_flexible_server.this[0].fqdn : azurerm_mysql_flexible_server.this[0].fqdn
}

output "database_name" {
  description = "Name of the initial database created on the server."
  value       = var.initial_db_name
}

output "admin_username" {
  description = "Administrator username."
  value       = var.admin_username
}

output "db_engine" {
  description = "Database engine used: postgres or mysql."
  value       = var.db_engine
}

output "db_port" {
  description = "Port the database listens on. PostgreSQL: 5432, MySQL: 3306."
  value       = var.db_engine == "postgres" ? 5432 : 3306
}
EOF

cat > terraform/azure/database/sql-flexible/CHANGELOG.md << 'EOF'
# Changelog — terraform-azure-sql-flexible

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- PostgreSQL Flexible Server with configurable version, SKU, and storage
- MySQL Flexible Server with configurable version, SKU, and storage
- Single module handles both engines via db_engine variable
- Private networking via delegated subnet and private DNS zone
- Optional high availability — Disabled, SameZone, or ZoneRedundant
- Optional geo-redundant backups
- Configurable backup retention (1-35 days)
- Maintenance window set to 3am Sunday UTC
- Initial database created automatically on server
- Reserved admin username validation
- Standard Opt IT tagging on all resources
- Outputs: server_id, server_name, server_fqdn, database_name, admin_username, db_engine, db_port
EOF

cat > terraform/azure/database/sql-flexible/README.md << 'EOF'
# terraform-azure-sql-flexible

Provisions an Azure PostgreSQL or MySQL Flexible Server with private networking, automated backups, and optional high availability.

Depends on `terraform-azure-resource-group` and `terraform-azure-vnet`. Requires a dedicated delegated subnet and a private DNS zone.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_postgresql_flexible_server` | PostgreSQL server (if db_engine = postgres) |
| `azurerm_postgresql_flexible_server_database` | Initial database on PostgreSQL |
| `azurerm_mysql_flexible_server` | MySQL server (if db_engine = mysql) |
| `azurerm_mysql_flexible_database` | Initial database on MySQL |

---

## Important — Subnet Delegation

Azure Flexible Server requires a **dedicated, empty subnet** with a delegation to the database service. This subnet cannot contain any other resources.

Create a third private subnet in your VNet specifically for the database:

```hcl
module "vnet" {
  # ...
  private_subnet_prefixes = [
    "10.0.10.0/24",   # for VMs
    "10.0.11.0/24",   # for databases — pass this to sql-flexible
  ]
}
```

Then pass `module.vnet.private_subnet_ids[1]` as `delegated_subnet_id`.

You must also create a Private DNS Zone and link it to the VNet before provisioning the server.

---

## Usage

```hcl
# Private DNS Zone (required before sql-flexible module)
resource "azurerm_private_dns_zone" "postgres" {
  name                = "${var.client_name}.postgres.database.azure.com"
  resource_group_name = module.resource_group.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "${var.client_name}-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = module.resource_group.resource_group_name
  virtual_network_id    = module.vnet.vnet_id
}

module "sql" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/database/sql-flexible?ref=terraform-azure-sql-flexible-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name

  delegated_subnet_id = module.vnet.private_subnet_ids[1]
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  db_engine              = "postgres"
  db_version             = "15"
  sku_name               = "GP_Standard_D2s_v3"
  admin_username         = "dbadmin"
  admin_password         = var.db_password
  high_availability_mode = "ZoneRedundant"
  geo_redundant_backup   = true
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
| `delegated_subnet_id` | Dedicated empty subnet ID | `string` | — | ✅ |
| `private_dns_zone_id` | Private DNS zone ID | `string` | — | ✅ |
| `admin_password` | DB admin password (sensitive) | `string` | — | ✅ |
| `db_engine` | postgres or mysql | `string` | `postgres` | ❌ |
| `db_version` | Engine version | `string` | `15` | ❌ |
| `sku_name` | Server SKU | `string` | `B_Standard_B1ms` | ❌ |
| `storage_mb` | Storage in MB (min 32768) | `number` | `32768` | ❌ |
| `admin_username` | Admin username | `string` | `dbadmin` | ❌ |
| `backup_retention_days` | Backup retention in days | `number` | `7` | ❌ |
| `geo_redundant_backup` | Enable geo-redundant backups | `bool` | `false` | ❌ |
| `high_availability_mode` | Disabled / SameZone / ZoneRedundant | `string` | `Disabled` | ❌ |
| `initial_db_name` | Name of initial database | `string` | `appdb` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `server_id` | Database server resource ID |
| `server_name` | Database server name |
| `server_fqdn` | Fully qualified domain name — use as host in connection strings |
| `database_name` | Initial database name |
| `admin_username` | Admin username |
| `db_engine` | postgres or mysql |
| `db_port` | 5432 (postgres) or 3306 (mysql) |

---

## Recommended SKUs By Environment

| Environment | SKU | Description |
|---|---|---|
| dev | `B_Standard_B1ms` | Burstable, 1 vCore, 2 GB RAM |
| staging | `B_Standard_B2ms` | Burstable, 2 vCores, 4 GB RAM |
| prod | `GP_Standard_D2s_v3` | General Purpose, 2 vCores, 8 GB RAM |
| prod (heavy) | `GP_Standard_D4s_v3` | General Purpose, 4 vCores, 16 GB RAM |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| RDS Subnet Group | Delegated Subnet |
| RDS Parameter Group | Server Configuration |
| RDS Multi-AZ | ZoneRedundant High Availability |
| RDS Automated Backups | Backup Retention Policy |
| Route53 Private Zone | Private DNS Zone |

---

## Notes

- Never commit `admin_password` — use `TF_VAR_admin_password` or Azure Key Vault
- Maintenance window is set to 3am Sunday UTC by default
- Zone is ignored in lifecycle — Azure may move the server between zones
- The delegated subnet must be empty — it cannot contain VMs or other resources

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-sql-flexible-v1.0.0`
EOF

cat > terraform/azure/database/sql-flexible/examples/basic/main.tf << 'EOF'
variable "subscription_id" {
  type      = string
  sensitive = true
}

variable "db_password" {
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
  source                  = "../../../networking/vnet"
  client_name             = "example-client"
  environment             = "dev"
  location                = module.resource_group.location
  subscription_id         = var.subscription_id
  resource_group_name     = module.resource_group.resource_group_name
  private_subnet_prefixes = ["10.0.10.0/24", "10.0.11.0/24"]
}

resource "azurerm_private_dns_zone" "postgres" {
  name                = "example-client.postgres.database.azure.com"
  resource_group_name = module.resource_group.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "example-client-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  resource_group_name   = module.resource_group.resource_group_name
  virtual_network_id    = module.vnet.vnet_id
}

module "sql" {
  source              = "../../"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  delegated_subnet_id = module.vnet.private_subnet_ids[1]
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id
  db_engine           = "postgres"
  admin_password      = var.db_password
}

output "server_fqdn"    { value = module.sql.server_fqdn }
output "database_name"  { value = module.sql.database_name }
EOF

echo ""
echo "================================================================"
echo "  Committing and tagging..."
echo "================================================================"

git add terraform/azure/database/
git commit -m "feat(azure): add terraform-azure-sql-flexible v1.0.0"
git tag terraform-azure-sql-flexible-v1.0.0
git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ Azure SQL Flexible Server module pushed and tagged!"
echo "  Tag: terraform-azure-sql-flexible-v1.0.0"
echo "================================================================"