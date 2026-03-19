variable "subscription_id" {
  type      = string
  sensitive = true
}

module "resource_group" {
  source          = "../../"
  client_name     = "example-client"
  environment     = "dev"
  location        = "eastus"
  subscription_id = var.subscription_id
}

output "resource_group_name" { value = module.resource_group.resource_group_name }
output "location"            { value = module.resource_group.location }
