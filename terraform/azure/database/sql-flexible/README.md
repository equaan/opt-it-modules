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
