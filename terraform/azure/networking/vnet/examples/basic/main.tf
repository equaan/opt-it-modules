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
