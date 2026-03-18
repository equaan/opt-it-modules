# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-security-groups"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# WEB / APP SECURITY GROUP
# For EC2 instances serving HTTP/HTTPS traffic
# Allows: HTTP (80), HTTPS (443) inbound from configured CIDRs
#         SSH inbound from configured CIDRs only (empty = no SSH)
#         All outbound traffic
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-sg-web"
  description = "Web/App tier security group for ${var.client_name} ${var.environment}. Managed by Opt IT Backstage."
  vpc_id      = var.vpc_id

  # HTTP inbound
  dynamic "ingress" {
    for_each = length(var.allowed_http_cidrs) > 0 ? [1] : []
    content {
      description = "HTTP inbound"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = var.allowed_http_cidrs
    }
  }

  # HTTPS inbound
  dynamic "ingress" {
    for_each = length(var.allowed_https_cidrs) > 0 ? [1] : []
    content {
      description = "HTTPS inbound"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = var.allowed_https_cidrs
    }
  }

  # SSH inbound — only if allowed_ssh_cidrs is provided
  # Intentionally empty by default — force explicit opt-in
  dynamic "ingress" {
    for_each = length(var.allowed_ssh_cidrs) > 0 ? [1] : []
    content {
      description = "SSH inbound — restricted to approved IP ranges"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.allowed_ssh_cidrs
    }
  }

  # All outbound — EC2 instances need to reach package repos, APIs, etc.
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-sg-web"
    Tier = "web"
  })

  lifecycle {
    # Prevent destroy if referenced by running instances
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────────────────────────
# DATABASE SECURITY GROUP
# For RDS instances
# Allows: DB port inbound from web SG only (no direct internet access)
#         No outbound needed for RDS
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "database" {
  name        = "${local.name_prefix}-sg-database"
  description = "Database tier security group for ${var.client_name} ${var.environment}. Allows inbound from web SG only. Managed by Opt IT Backstage."
  vpc_id      = var.vpc_id

  # DB port inbound — from web SG only, not from the internet
  ingress {
    description     = "Database port inbound from web/app tier only"
    from_port       = var.rds_port
    to_port         = var.rds_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # No egress rule — RDS does not need outbound internet access

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-sg-database"
    Tier = "database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────────────────────────
# INTERNAL SECURITY GROUP
# For internal services that only communicate within the VPC
# Example: microservices, internal APIs, cache layers
# ─────────────────────────────────────────────────────────────

resource "aws_security_group" "internal" {
  name        = "${local.name_prefix}-sg-internal"
  description = "Internal services security group for ${var.client_name} ${var.environment}. VPC-internal traffic only. Managed by Opt IT Backstage."
  vpc_id      = var.vpc_id

  # All traffic within VPC CIDR
  ingress {
    description = "All inbound traffic from within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound within VPC
  egress {
    description = "All outbound traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-sg-internal"
    Tier = "internal"
  })

  lifecycle {
    create_before_destroy = true
  }
}
