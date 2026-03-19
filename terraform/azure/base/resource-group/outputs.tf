output "resource_group_name" {
  description = "Resource group name — pass to every other Azure module."
  value       = azurerm_resource_group.this.name
}

output "resource_group_id" {
  description = "Full resource ID of the resource group."
  value       = azurerm_resource_group.this.id
}

output "location" {
  description = "Azure region — pass to every other Azure module."
  value       = azurerm_resource_group.this.location
}

output "name_prefix" {
  description = "Naming prefix used across all resources."
  value       = local.name_prefix
}

output "standard_tags" {
  description = "Standard tags applied to all resources."
  value       = local.standard_tags
}
