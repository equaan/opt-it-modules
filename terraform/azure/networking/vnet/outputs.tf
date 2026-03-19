output "vnet_id" {
  description = "The ID of the Virtual Network. Pass to NSG and VM modules."
  value       = azurerm_virtual_network.this.id
}

output "vnet_name" {
  description = "The name of the Virtual Network."
  value       = azurerm_virtual_network.this.name
}

output "vnet_address_space" {
  description = "The address space of the VNet."
  value       = azurerm_virtual_network.this.address_space
}

output "public_subnet_ids" {
  description = "List of public subnet IDs."
  value       = azurerm_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs. Pass to VM and SQL modules."
  value       = azurerm_subnet.private[*].id
}

output "public_subnet_names" {
  description = "List of public subnet names."
  value       = azurerm_subnet.public[*].name
}

output "private_subnet_names" {
  description = "List of private subnet names."
  value       = azurerm_subnet.private[*].name
}

output "nat_gateway_id" {
  description = "NAT Gateway ID. Empty string if enable_nat_gateway = false."
  value       = var.enable_nat_gateway ? azurerm_nat_gateway.this[0].id : ""
}
