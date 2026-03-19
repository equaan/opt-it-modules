# terraform-azure-blob-storage

Provisions an Azure Storage Account with private blob containers, HTTPS enforced, and optional versioning and soft delete.

Depends on `terraform-azure-resource-group`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `azurerm_storage_account` | The storage account with security defaults |
| `azurerm_storage_container` | One per entry in container_names |

---

## Usage

```hcl
module "storage" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/storage/blob?ref=terraform-azure-blob-storage-v1.0.0"

  client_name         = "acme-corp"
  environment         = "prod"
  location            = module.resource_group.location
  subscription_id     = var.subscription_id
  resource_group_name = module.resource_group.resource_group_name

  storage_suffix           = "data"
  account_replication_type = "GRS"
  enable_versioning        = true
  enable_soft_delete       = true
  container_names          = ["uploads", "backups", "exports"]
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
| `storage_suffix` | Short suffix (max 5 chars, no hyphens) | `string` | `store` | ❌ |
| `account_replication_type` | LRS / GRS / ZRS etc. | `string` | `LRS` | ❌ |
| `enable_versioning` | Enable blob versioning | `bool` | `false` | ❌ |
| `enable_soft_delete` | Enable soft delete | `bool` | `true` | ❌ |
| `soft_delete_retention_days` | Soft delete retention in days | `number` | `7` | ❌ |
| `container_names` | List of container names to create | `list(string)` | `["default"]` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `storage_account_id` | Storage account resource ID |
| `storage_account_name` | Storage account name |
| `primary_blob_endpoint` | Blob service endpoint URL |
| `primary_access_key` | Primary access key (sensitive) |
| `primary_connection_string` | Primary connection string (sensitive) |
| `container_names` | List of created container names |

---

## AWS Equivalent

| AWS | Azure |
|---|---|
| S3 Bucket | Storage Account |
| S3 Prefix / Folder | Blob Container |
| Bucket Policy | Storage Account access keys / RBAC |
| S3 Versioning | Blob Versioning |
| S3 Object expiry | Soft Delete retention |

---

## Storage Account Naming

Azure storage account names must be globally unique, 3-24 characters, lowercase alphanumeric only — no hyphens. This module auto-generates the name:

```
{client_name}{environment}{suffix}  →  hyphens stripped, truncated to 24 chars

Examples:
  acme-corp + prod + data  →  acmecorpproddata
  my-client + staging + bkp  →  myclientstagingbkp
```

---

## Replication Types

| Type | Description | Use case |
|---|---|---|
| `LRS` | Locally redundant — 3 copies in one datacenter | dev |
| `ZRS` | Zone redundant — 3 copies across AZs | staging |
| `GRS` | Geo redundant — copies to secondary region | prod |
| `RAGRS` | Read-access geo redundant — readable from secondary | prod (read-heavy) |

---

## Notes

- HTTPS-only and TLS 1.2 minimum are always enforced
- All containers are private — anonymous public access is blocked
- Store `primary_access_key` and `primary_connection_string` in Azure Key Vault — never in code

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-azure-blob-storage-v1.0.0`
