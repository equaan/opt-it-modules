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
      Module        = "terraform-azure-vnet"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# VIRTUAL NETWORK
# ─────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "this" {
  name                = "${local.name_prefix}-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = local.standard_tags
}

# ─────────────────────────────────────────────────────────────
# PUBLIC SUBNETS
# Internet-facing resources — load balancers, bastion hosts
# ─────────────────────────────────────────────────────────────

resource "azurerm_subnet" "public" {
  count                = length(var.public_subnet_prefixes)
  name                 = "${local.name_prefix}-public-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.public_subnet_prefixes[count.index]]
}

# ─────────────────────────────────────────────────────────────
# PRIVATE SUBNETS
# Internal resources — VMs, databases, app servers
# ─────────────────────────────────────────────────────────────

resource "azurerm_subnet" "private" {
  count                = length(var.private_subnet_prefixes)
  name                 = "${local.name_prefix}-private-subnet-${count.index + 1}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.private_subnet_prefixes[count.index]]
}

# ─────────────────────────────────────────────────────────────
# NAT GATEWAY — optional
# Allows private subnet resources to reach the internet
# ─────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${local.name_prefix}-nat-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.standard_tags
}

resource "azurerm_nat_gateway" "this" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "${local.name_prefix}-nat"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = local.standard_tags
}

resource "azurerm_nat_gateway_public_ip_association" "this" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.this[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

# Associate NAT Gateway with all private subnets
resource "azurerm_subnet_nat_gateway_association" "private" {
  count          = var.enable_nat_gateway ? length(azurerm_subnet.private) : 0
  subnet_id      = azurerm_subnet.private[count.index].id
  nat_gateway_id = azurerm_nat_gateway.this[0].id
}
