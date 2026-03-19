output "server_id" {
  description = "The ID of the database server."
  value       = var.db_engine == "postgres" ? azurerm_postgresql_flexible_server.this[0].id : azurerm_mysql_flexible_server.this[0].id
}

output "server_name" {
  description = "The name of the database server."
  value       = var.db_engine == "postgres" ? azurerm_postgresql_flexible_server.this[0].name : azurerm_mysql_flexible_server.this[0].name
}

output "server_fqdn" {
  description = "Fully qualified domain name of the database server. Use this as the host in connection strings."
  value       = var.db_engine == "postgres" ? azurerm_postgresql_flexible_server.this[0].fqdn : azurerm_mysql_flexible_server.this[0].fqdn
}

output "database_name" {
  description = "Name of the initial database created on the server."
  value       = var.initial_db_name
}

output "admin_username" {
  description = "Administrator username."
  value       = var.admin_username
}

output "db_engine" {
  description = "Database engine used: postgres or mysql."
  value       = var.db_engine
}

output "db_port" {
  description = "Port the database listens on. PostgreSQL: 5432, MySQL: 3306."
  value       = var.db_engine == "postgres" ? 5432 : 3306
}
