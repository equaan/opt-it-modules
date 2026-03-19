output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.this.private_ip_address
  sensitive   = true
}

output "connection_name" {
  description = "Cloud SQL connection name. Format: project:region:instance. Used by Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.this.connection_name
}

output "database_name" {
  description = "Name of the initial database created."
  value       = google_sql_database.this.name
}

output "db_port" {
  description = "Port the database listens on. PostgreSQL: 5432, MySQL: 3306."
  value       = var.db_engine == "postgres" ? 5432 : 3306
}
