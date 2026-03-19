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

module "storage" {
  source              = "../../"
  client_name         = "example-client"
  environment         = "dev"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  storage_suffix      = "data"
  container_names     = ["uploads", "backups"]
}

output "storage_account_name" { value = module.storage.storage_account_name }
output "primary_blob_endpoint" { value = module.storage.primary_blob_endpoint }
