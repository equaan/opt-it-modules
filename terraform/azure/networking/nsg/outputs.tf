output "public_nsg_id" {
  description = "ID of the public NSG. Pass to VM module if needed."
  value       = azurerm_network_security_group.public.id
}

output "public_nsg_name" {
  description = "Name of the public NSG."
  value       = azurerm_network_security_group.public.name
}

output "private_nsg_id" {
  description = "ID of the private NSG."
  value       = azurerm_network_security_group.private.id
}

output "private_nsg_name" {
  description = "Name of the private NSG."
  value       = azurerm_network_security_group.private.name
}
