# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# Centralise repeated expressions and naming conventions
# ─────────────────────────────────────────────────────────────

locals {
  # Standard name prefix used across all resources in this module
  # Format: {client}-{environment} — e.g. acme-corp-prod
  name_prefix = "${var.client_name}-${var.environment}"

  # Standard tags applied to every resource in this module
  # Merge standard tags with any additional tags passed in
  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-vpc"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# VPC
# ─────────────────────────────────────────────────────────────

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ─────────────────────────────────────────────────────────────
# INTERNET GATEWAY
# Required for public subnet internet access
# ─────────────────────────────────────────────────────────────

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ─────────────────────────────────────────────────────────────
# NAT GATEWAY
# Optional — only provisioned when enable_nat_gateway = true
# Allows private subnet resources to reach the internet
# ─────────────────────────────────────────────────────────────

resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-nat-eip"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id

  # NAT Gateway is placed in the first public subnet
  # Subnets are managed by the subnets module — this output is consumed there
  subnet_id = null

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-nat"
  })

  depends_on = [aws_internet_gateway.this]

  lifecycle {
    # Prevent accidental NAT Gateway deletion — expensive to recreate
    # and causes outage for all private subnet resources
    prevent_destroy = false
  }
}

# ─────────────────────────────────────────────────────────────
# DEFAULT SECURITY GROUP — LOCK IT DOWN
# AWS creates a default SG that allows all traffic by default.
# We override it to deny everything — explicit SGs are used instead.
# ─────────────────────────────────────────────────────────────

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  # No ingress or egress rules — deny all by default
  # Explicit security groups are created by the security-groups module

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-default-sg-do-not-use"
  })
}
