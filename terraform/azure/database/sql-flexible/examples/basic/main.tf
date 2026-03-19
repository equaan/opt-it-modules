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
