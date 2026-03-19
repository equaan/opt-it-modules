# terraform-azure-vm

Provisions an Azure Linux Virtual Machine with NIC, optional public IP, SSH key auth, and encrypted OS disk.

Depends on `terraform-azure-resource-group` and `terraform-azure-vnet`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_network_interface` | NIC connecting VM to subnet |
| `azurerm_public_ip` | Optional static public IP |
| `azurerm_linux_virtual_machine` | The VM with encrypted OS disk |

---

## Usage

```hcl
module "vm" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/compute/vm?ref=terraform-azure-vm-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name
  subnet_id           = module.vnet.private_subnet_ids[0]

  vm_size              = "Standard_D2s_v3"
  admin_username       = "azureuser"
  admin_ssh_public_key = file("~/.ssh/id_rsa.pub")
  os_disk_type         = "Premium_LRS"
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
| `subnet_id` | Subnet ID from vnet module | `string` | — | ✅ |
| `vm_size` | Azure VM size | `string` | `Standard_B2s` | ❌ |
| `admin_username` | VM admin username | `string` | `azureuser` | ❌ |
| `admin_ssh_public_key` | SSH public key content | `string` | `""` | ❌ |
| `os_disk_size_gb` | OS disk size in GB | `number` | `30` | ❌ |
| `os_disk_type` | OS disk storage type | `string` | `Standard_LRS` | ❌ |
| `enable_public_ip` | Assign public IP to VM | `bool` | `false` | ❌ |
| `custom_data` | Cloud-init script | `string` | `""` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `vm_id` | VM resource ID |
| `vm_name` | VM name |
| `private_ip_address` | Private IP |
| `public_ip_address` | Public IP (empty if disabled) |
| `nic_id` | Network Interface Card ID |
| `admin_username` | Admin username |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| EC2 instance | Linux Virtual Machine |
| Security Group attachment | NSG on subnet (handled by nsg module) |
| No equivalent | Network Interface Card (required in Azure) |
| Key Pair | admin_ssh_key block |
| User Data | custom_data (cloud-init) |

---

## Recommended VM Sizes By Environment

| Environment | VM Size | vCPUs | RAM |
|---|---|---|---|
| dev | `Standard_B2s` | 2 | 4 GB |
| staging | `Standard_B2ms` | 2 | 8 GB |
| prod | `Standard_D2s_v3` | 2 | 8 GB (SSD) |
| prod (heavy) | `Standard_D4s_v3` | 4 | 16 GB (SSD) |

---

## Notes

- OS disk is always encrypted with platform-managed keys
- `delete_os_disk_on_deletion = false` is automatically set for prod
- Password authentication is disabled when SSH key is provided
- Boot diagnostics are always enabled
- Image version is ignored in lifecycle to prevent VM replacement on minor updates

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-vm-v1.0.0`
