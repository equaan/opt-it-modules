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
