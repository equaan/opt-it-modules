# terraform-azure-nsg

Provisions Network Security Groups for public and private subnets and associates them automatically.

In Azure, NSGs are attached to subnets — every resource in the subnet inherits the rules. This is different from AWS where security groups are attached to individual instances.

Depends on `terraform-azure-resource-group` and `terraform-azure-vnet`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_network_security_group` (public) | HTTP/HTTPS/optional SSH inbound, deny all else |
| `azurerm_network_security_group` (private) | DB port from VNet only, deny all else |
| `azurerm_network_security_rule` (x5) | Individual rules per NSG |
| `azurerm_subnet_network_security_group_association` | Associates NSGs with subnets |

---

## Usage

```hcl
module "nsg" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/networking/nsg?ref=terraform-azure-nsg-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  public_subnet_ids   = module.vnet.public_subnet_ids
  private_subnet_ids  = module.vnet.private_subnet_ids

  allowed_ssh_source_prefixes = ["203.0.113.10/32"]
  db_port                     = 5432
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `location` | Azure region | `string` | — | ✅ |
| `subscription_id` | Azure Subscription ID | `string` | — | ✅ |
| `resource_group_name` | Resource group name | `string` | — | ✅ |
| `public_subnet_ids` | Public subnet IDs from vnet module | `list(string)` | `[]` | ❌ |
| `private_subnet_ids` | Private subnet IDs from vnet module | `list(string)` | `[]` | ❌ |
| `allowed_ssh_source_prefixes` | IPs allowed SSH — empty = disabled | `list(string)` | `[]` | ❌ |
| `allowed_http_source_prefixes` | IPs allowed HTTP | `list(string)` | `["*"]` | ❌ |
| `allowed_https_source_prefixes` | IPs allowed HTTPS | `list(string)` | `["*"]` | ❌ |
| `db_port` | Database port: 1433, 3306, or 5432 | `number` | `5432` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `public_nsg_id` | Public NSG ID |
| `public_nsg_name` | Public NSG name |
| `private_nsg_id` | Private NSG ID |
| `private_nsg_name` | Private NSG name |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| Security Group (attached to instance) | NSG (attached to subnet) |
| Inbound/Outbound rules | Inbound/Outbound security rules with priority numbers |
| Implicit deny | Explicit deny rule at priority 4096 |

---

## Security Notes

- SSH from `*` or `0.0.0.0/0` is blocked by a validation rule
- Private subnets only allow DB traffic from within the VNet
- All other inbound is explicitly denied at priority 4096
- NSGs are automatically associated with subnets — no manual wiring needed

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-nsg-v1.0.0`
