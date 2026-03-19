output "vm_id" {
  description = "The ID of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.id
}

output "vm_name" {
  description = "The name of the virtual machine."
  value       = azurerm_linux_virtual_machine.this.name
}

output "private_ip_address" {
  description = "Private IP address of the VM."
  value       = azurerm_network_interface.this.private_ip_address
}

output "public_ip_address" {
  description = "Public IP address of the VM. Empty string if enable_public_ip = false."
  value       = var.enable_public_ip ? azurerm_public_ip.vm[0].ip_address : ""
}

output "nic_id" {
  description = "Network Interface Card ID."
  value       = azurerm_network_interface.this.id
}

output "admin_username" {
  description = "Admin username for SSH access."
  value       = azurerm_linux_virtual_machine.this.admin_username
}
