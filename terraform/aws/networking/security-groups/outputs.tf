# ─────────────────────────────────────────────────────────────
# SECURITY GROUP OUTPUTS
# Consumed by ec2 and rds modules
# ─────────────────────────────────────────────────────────────

output "web_security_group_id" {
  description = "ID of the web/app tier security group. Pass to ec2 module as security_group_ids."
  value       = aws_security_group.web.id
}

output "database_security_group_id" {
  description = "ID of the database tier security group. Pass to rds module as vpc_security_group_ids."
  value       = aws_security_group.database.id
}

output "internal_security_group_id" {
  description = "ID of the internal services security group. Use for services that only communicate within the VPC."
  value       = aws_security_group.internal.id
}

output "web_security_group_name" {
  description = "Name of the web/app tier security group."
  value       = aws_security_group.web.name
}

output "database_security_group_name" {
  description = "Name of the database tier security group."
  value       = aws_security_group.database.name
}
