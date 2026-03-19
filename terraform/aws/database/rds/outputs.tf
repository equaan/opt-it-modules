output "db_instance_id" {
  description = "The RDS instance identifier."
  value       = aws_db_instance.this.id
}

output "db_instance_arn" {
  description = "The ARN of the RDS instance."
  value       = aws_db_instance.this.arn
}

output "db_endpoint" {
  description = "The connection endpoint of the RDS instance. Format: hostname:port"
  value       = aws_db_instance.this.endpoint
}

output "db_host" {
  description = "The hostname of the RDS instance."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "The port the RDS instance listens on."
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "The name of the initial database."
  value       = aws_db_instance.this.db_name
}

output "db_subnet_group_name" {
  description = "The name of the RDS subnet group."
  value       = aws_db_subnet_group.this.name
}
