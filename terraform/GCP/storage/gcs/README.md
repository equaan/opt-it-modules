# terraform-gcp-gcs

Provisions a GCS (Google Cloud Storage) bucket with public access blocked and uniform access control enforced.

---

## Usage

```hcl
module "gcs" {
  source = "github.com/equaan/opt-it-modules//terraform/gcp/storage/gcs?ref=terraform-gcp-gcs-v1.0.0"

  client_name       = "acme-corp"
  environment       = "prod"
  project_id        = "acme-corp-prod-123456"
  location          = "US"
  bucket_suffix     = "assets"
  enable_versioning = true
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `project_id` | GCP Project ID | `string` | — | ✅ |
| `location` | Bucket location | `string` | `US` | ❌ |
| `bucket_suffix` | Bucket name suffix | `string` | `storage` | ❌ |
| `storage_class` | STANDARD/NEARLINE/COLDLINE/ARCHIVE | `string` | `STANDARD` | ❌ |
| `enable_versioning` | Enable object versioning | `bool` | `false` | ❌ |
| `soft_delete_retention_days` | Soft delete retention | `number` | `7` | ❌ |
| `force_destroy` | Allow destroy with objects | `bool` | `false` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `bucket_name` | Bucket name |
| `bucket_url` | gs://bucket-name |
| `bucket_self_link` | Bucket self_link |

---

## Module Version

`terraform-gcp-gcs-v1.0.0`
