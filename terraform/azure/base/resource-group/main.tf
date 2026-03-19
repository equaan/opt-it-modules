provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

locals {
  name_prefix         = "${var.client_name}-${var.environment}"
  resource_group_name = var.resource_group_suffix != "" ? "${local.name_prefix}-${var.resource_group_suffix}-rg" : "${local.name_prefix}-rg"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-azure-resource-group"
      Location      = var.location
    },
    var.additional_tags
  )
}

resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.standard_tags
}
