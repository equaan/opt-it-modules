# ─────────────────────────────────────────────────────────────
# PROVIDER
# ─────────────────────────────────────────────────────────────

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

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
      Module        = "terraform-azure-nsg"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# PUBLIC NSG
# Applied to public subnets
# Allows: HTTP, HTTPS inbound from configured sources
#         SSH inbound from configured IPs only (empty = disabled)
#         All outbound
# ─────────────────────────────────────────────────────────────

resource "azurerm_network_security_group" "public" {
  name                = "${local.name_prefix}-nsg-public"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(local.standard_tags, { Tier = "public" })
}

# HTTP inbound
resource "azurerm_network_security_rule" "public_http" {
  count                       = length(var.allowed_http_source_prefixes) > 0 ? 1 : 0
  name                        = "Allow-HTTP-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = var.allowed_http_source_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# HTTPS inbound
resource "azurerm_network_security_rule" "public_https" {
  count                       = length(var.allowed_https_source_prefixes) > 0 ? 1 : 0
  name                        = "Allow-HTTPS-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.allowed_https_source_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# SSH inbound — only if allowed_ssh_source_prefixes is provided
resource "azurerm_network_security_rule" "public_ssh" {
  count                       = length(var.allowed_ssh_source_prefixes) > 0 ? 1 : 0
  name                        = "Allow-SSH-Inbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = var.allowed_ssh_source_prefixes
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# Deny all other inbound
resource "azurerm_network_security_rule" "public_deny_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.public.name
}

# Associate public NSG with all public subnets
resource "azurerm_subnet_network_security_group_association" "public" {
  count                     = length(var.public_subnet_ids)
  subnet_id                 = var.public_subnet_ids[count.index]
  network_security_group_id = azurerm_network_security_group.public.id
}

# ─────────────────────────────────────────────────────────────
# PRIVATE NSG
# Applied to private subnets
# Allows: DB port inbound from public subnet CIDRs only
#         All outbound (for package installs, API calls etc.)
# ─────────────────────────────────────────────────────────────

resource "azurerm_network_security_group" "private" {
  name                = "${local.name_prefix}-nsg-private"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = merge(local.standard_tags, { Tier = "private" })
}

# DB port inbound from VNet only — databases only reachable internally
resource "azurerm_network_security_rule" "private_db" {
  name                        = "Allow-DB-Inbound-VNet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(var.db_port)
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
}

# Deny all other inbound to private subnets
resource "azurerm_network_security_rule" "private_deny_inbound" {
  name                        = "Deny-All-Inbound"
  priority                    = 4096
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.private.name
}

# Associate private NSG with all private subnets
resource "azurerm_subnet_network_security_group_association" "private" {
  count                     = length(var.private_subnet_ids)
  subnet_id                 = var.private_subnet_ids[count.index]
  network_security_group_id = azurerm_network_security_group.private.id
}
