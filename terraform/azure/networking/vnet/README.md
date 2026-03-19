# terraform-azure-vnet

Provisions an Azure Virtual Network with public and private subnets and an optional NAT Gateway.

In Azure, VNet and Subnets are managed together — this module replaces both the `vpc` and `subnets` modules from the AWS stack.

Depends on `terraform-azure-resource-group`. Consumes `resource_group_name` and `location` from its outputs.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_virtual_network` | The VNet |
| `azurerm_subnet` (public) | One per entry in public_subnet_prefixes |
| `azurerm_subnet` (private) | One per entry in private_subnet_prefixes |
| `azurerm_public_ip` | Static public IP for NAT Gateway (if enabled) |
| `azurerm_nat_gateway` | NAT Gateway for private subnet egress (if enabled) |
| `azurerm_nat_gateway_public_ip_association` | Links NAT Gateway to public IP |
| `azurerm_subnet_nat_gateway_association` | Associates NAT Gateway with private subnets |

---

## Usage

```hcl
module "vnet" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/networking/vnet?ref=terraform-azure-vnet-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name

  vnet_address_space      = ["10.0.0.0/16"]
  public_subnet_prefixes  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_prefixes = ["10.0.10.0/24", "10.0.11.0/24"]
  enable_nat_gateway      = true
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `location` | Azure region from resource_group module | `string` | — | ✅ |
| `subscription_id` | Azure Subscription ID | `string` | — | ✅ |
| `resource_group_name` | Resource group name from resource_group module | `string` | — | ✅ |
| `vnet_address_space` | VNet CIDR address space | `list(string)` | `["10.0.0.0/16"]` | ❌ |
| `public_subnet_prefixes` | Public subnet CIDRs | `list(string)` | `["10.0.1.0/24","10.0.2.0/24"]` | ❌ |
| `private_subnet_prefixes` | Private subnet CIDRs | `list(string)` | `["10.0.10.0/24","10.0.11.0/24"]` | ❌ |
| `enable_nat_gateway` | Provision NAT Gateway | `bool` | `false` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `vnet_id` | VNet ID |
| `vnet_name` | VNet name |
| `vnet_address_space` | VNet address space |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs — pass to VM and SQL modules |
| `public_subnet_names` | List of public subnet names |
| `private_subnet_names` | List of private subnet names |
| `nat_gateway_id` | NAT Gateway ID (empty if disabled) |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| VPC | Virtual Network (VNet) |
| Subnet | Subnet (inside VNet) |
| Internet Gateway | Handled automatically by Azure |
| NAT Gateway | NAT Gateway (same concept, different resource) |

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-vnet-v1.0.0`
