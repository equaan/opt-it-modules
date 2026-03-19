# terraform-aws-rds

Provisions an RDS instance (MySQL or PostgreSQL) with encryption, automated backups, and production safeguards.

Depends on `terraform-aws-subnets` and `terraform-aws-security-groups`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_db_subnet_group` | Subnet group spanning private subnets across AZs |
| `aws_db_instance` | The RDS instance |

---

## Usage

```hcl
module "rds" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/database/rds?ref=terraform-aws-rds-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"

  subnet_ids         = module.subnets.private_subnet_ids
  security_group_ids = [module.security_groups.database_security_group_id]

  engine          = "postgres"
  engine_version  = "15.4"
  instance_class  = "db.t3.medium"
  database_name   = "appdb"
  master_username = "dbadmin"
  master_password = var.db_password  # from secrets manager

  multi_az              = true
  backup_retention_days = 14
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `subnet_ids` | Private subnet IDs (min 2) | `list(string)` | — | ✅ |
| `security_group_ids` | Security group IDs | `list(string)` | — | ✅ |
| `master_password` | DB master password (sensitive) | `string` | — | ✅ |
| `engine` | mysql or postgres | `string` | `postgres` | ❌ |
| `engine_version` | Engine version | `string` | `15.4` | ❌ |
| `instance_class` | RDS instance class | `string` | `db.t3.micro` | ❌ |
| `allocated_storage` | Initial storage in GB | `number` | `20` | ❌ |
| `max_allocated_storage` | Max storage for autoscaling | `number` | `100` | ❌ |
| `database_name` | Initial database name | `string` | `appdb` | ❌ |
| `master_username` | Master username | `string` | `dbadmin` | ❌ |
| `multi_az` | Enable Multi-AZ | `bool` | `false` | ❌ |
| `backup_retention_days` | Backup retention in days | `number` | `7` | ❌ |
| `deletion_protection` | Enable deletion protection | `bool` | `false` | ❌ |
| `skip_final_snapshot` | Skip final snapshot on delete | `bool` | `true` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `db_instance_id` | RDS instance identifier |
| `db_instance_arn` | RDS instance ARN |
| `db_endpoint` | Connection endpoint (hostname:port) |
| `db_host` | Hostname only |
| `db_port` | Port number |
| `db_name` | Database name |
| `db_subnet_group_name` | Subnet group name |

---

## Notes

- `publicly_accessible` is always false — RDS is never exposed to the internet
- Storage is always encrypted
- For prod: deletion protection and final snapshot are automatically enforced
- Never commit `master_password` to git — use AWS Secrets Manager or Terraform Cloud variables

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-rds-v1.0.0`
