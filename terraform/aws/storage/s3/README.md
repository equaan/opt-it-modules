# terraform-aws-s3

Provisions a secure S3 bucket with public access blocked and encryption enforced by default.

No VPC dependency — S3 is a global AWS service.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_s3_bucket` | The S3 bucket |
| `aws_s3_bucket_public_access_block` | Blocks all public access — always enabled |
| `aws_s3_bucket_server_side_encryption_configuration` | AES256 encryption — always enabled |
| `aws_s3_bucket_versioning` | Optional versioning |
| `aws_s3_bucket_lifecycle_configuration` | Optional lifecycle rules for old versions |

---

## Usage

```hcl
module "s3" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/storage/s3?ref=terraform-aws-s3-v1.0.0"

  client_name   = "acme-corp"
  environment   = "prod"
  bucket_suffix = "uploads"

  enable_versioning      = true
  enable_lifecycle_rules = true
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `bucket_suffix` | Suffix for bucket name | `string` | `storage` | ❌ |
| `enable_versioning` | Enable versioning | `bool` | `false` | ❌ |
| `enable_lifecycle_rules` | Enable lifecycle rules | `bool` | `false` | ❌ |
| `noncurrent_version_transition_days` | Days to transition old versions to STANDARD_IA | `number` | `30` | ❌ |
| `noncurrent_version_expiration_days` | Days to expire old versions | `number` | `90` | ❌ |
| `force_destroy` | Allow destroy with objects — false for prod | `bool` | `false` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `bucket_id` | Bucket name |
| `bucket_arn` | Bucket ARN — use in IAM policies |
| `bucket_domain_name` | Bucket domain name |
| `bucket_regional_domain_name` | Regional domain name |

---

## Notes

- Public access block and encryption are always enforced and cannot be disabled
- Set `force_destroy = false` for prod to prevent accidental data loss
- Bucket name format: `{client_name}-{environment}-{bucket_suffix}`

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-s3-v1.0.0`
