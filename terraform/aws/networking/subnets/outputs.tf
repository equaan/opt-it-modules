# ─────────────────────────────────────────────────────────────
# VPC OUTPUTS
# These are consumed by other modules (subnets, ec2, rds, eks)
# ─────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "The ID of the VPC. Consumed by subnets, security-groups, ec2, rds, and eks modules."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway attached to this VPC."
  value       = aws_internet_gateway.this.id
}

output "nat_gateway_id" {
  description = "The ID of the NAT Gateway. Empty string if enable_nat_gateway = false."
  value       = var.enable_nat_gateway ? aws_nat_gateway.this[0].id : ""
}

output "nat_gateway_public_ip" {
  description = "The public IP of the NAT Gateway. Empty string if enable_nat_gateway = false."
  value       = var.enable_nat_gateway ? aws_eip.nat[0].public_ip : ""
}

output "default_security_group_id" {
  description = "The ID of the locked-down default security group. Do not use this — it denies all traffic by design."
  value       = aws_default_security_group.this.id
}

output "name_prefix" {
  description = "The name prefix used for all resources in this module. Useful for other modules to follow the same naming convention."
  value       = local.name_prefix
}

output "standard_tags" {
  description = "The standard tags applied to all resources. Useful for other modules to inherit the same tags."
  value       = local.standard_tags
}
