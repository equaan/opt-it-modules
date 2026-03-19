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
