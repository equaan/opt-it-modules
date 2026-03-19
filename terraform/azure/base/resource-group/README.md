# terraform-azure-resource-group

Provisions an Azure Resource Group — the mandatory container for all Azure resources.

This is always the first module to run in any Azure deployment. Pass its outputs to every other Azure module.

## Usage

```hcl
module "resource_group" {
  source = "github.com/equaan/opt-it-modules//terraform/azure/base/resource-group?ref=terraform-azure-resource-group-v1.0.0"

  client_name     = "acme-corp"
  environment     = "prod"
  location        = "eastus"
  subscription_id = var.subscription_id
}
```

## Inputs

| Name | Description | Type | Required |
|---|---|---|---|
| `client_name` | Client name | `string` | ✅ |
| `environment` | dev / staging / prod | `string` | ✅ |
| `location` | Azure region | `string` | ✅ |
| `subscription_id` | Azure Subscription ID | `string` | ✅ |
| `module_version` | Module version | `string` | ❌ |
| `resource_group_suffix` | Optional name suffix | `string` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | ❌ |

## Outputs

| Name | Description |
|---|---|
| `resource_group_name` | Pass to every other Azure module |
| `resource_group_id` | Full resource ID |
| `location` | Pass to every other Azure module |
| `name_prefix` | Naming prefix |
| `standard_tags` | Standard tags |

## Authentication

```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

## Module Version

`terraform-azure-resource-group-v1.0.0`
