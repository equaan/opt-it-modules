# terraform-gcp-cloud-sql

Provisions a Cloud SQL instance (PostgreSQL or MySQL) with private IP, automated backups, and optional HA.

Depends on `terraform-gcp-vpc`.

---

## Usage

```hcl
module "cloud_sql" {
  source = "github.com/equaan/opt-it-modules//terraform/gcp/database/cloud-sql?ref=terraform-gcp-cloud-sql-v1.0.0"

  client_name       = "acme-corp"
  environment       = "prod"
  project_id        = "acme-corp-prod-123456"
  region            = "us-central1"
  vpc_self_link     = module.vpc.vpc_self_link
  db_engine         = "postgres"
  db_version        = "POSTGRES_15"
  tier              = "db-n1-standard-2"
  availability_type = "REGIONAL"
  admin_password    = var.db_password
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `project_id` | GCP Project ID | `string` | — | ✅ |
| `region` | GCP region | `string` | `us-central1` | ❌ |
| `vpc_self_link` | VPC self_link from vpc module | `string` | — | ✅ |
| `admin_password` | DB admin password (sensitive) | `string` | — | ✅ |
| `db_engine` | postgres or mysql | `string` | `postgres` | ❌ |
| `db_version` | Engine version | `string` | `POSTGRES_15` | ❌ |
| `tier` | Machine tier | `string` | `db-f1-micro` | ❌ |
| `disk_size_gb` | Storage size in GB | `number` | `10` | ❌ |
| `backup_enabled` | Enable automated backups | `bool` | `true` | ❌ |
| `availability_type` | ZONAL or REGIONAL | `string` | `ZONAL` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `instance_name` | Cloud SQL instance name |
| `private_ip_address` | Private IP (sensitive) |
| `connection_name` | Connection name for Cloud SQL Auth Proxy |
| `database_name` | Initial database name |
| `db_port` | 5432 (postgres) or 3306 (mysql) |

---

## Module Version

`terraform-gcp-cloud-sql-v1.0.0`
