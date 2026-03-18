# terraform-aws-security-groups

Provisions three baseline security groups for a standard client environment: web/app tier, database tier, and internal services.

Depends on the `terraform-aws-vpc` module. Consumes `vpc_id` and `vpc_cidr`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_security_group` (web) | HTTP/HTTPS inbound, optional SSH, all outbound |
| `aws_security_group` (database) | DB port inbound from web SG only — no internet access |
| `aws_security_group` (internal) | VPC-internal traffic only — no internet access |

---

## Security Design

The three security groups map to a standard three-tier architecture:

```
Internet
    │
    ▼
[web SG]        ← EC2 app servers, load balancers
    │
    ▼
[database SG]   ← RDS — only reachable from web SG
    
[internal SG]   ← Internal services, cache — VPC only
```

The database SG references the web SG as its source — meaning only resources attached to the web SG can connect to the database. Direct internet access to the database is impossible by design.

---

## Usage

```hcl
module "security_groups" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/networking/security-groups?ref=terraform-aws-security-groups-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"

  vpc_id   = module.vpc.vpc_id
  vpc_cidr = module.vpc.vpc_cidr

  # Restrict SSH to your office/VPN IP — never use 0.0.0.0/0
  allowed_ssh_cidrs = ["203.0.113.10/32"]

  rds_port = 5432  # PostgreSQL
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name — lowercase alphanumeric and hyphens | `string` | — | ✅ |
| `environment` | Deployment environment: dev / staging / prod | `string` | — | ✅ |
| `module_version` | Module version — injected by Backstage | `string` | `"1.0.0"` | ❌ |
| `vpc_id` | VPC ID from vpc module | `string` | — | ✅ |
| `vpc_cidr` | VPC CIDR from vpc module | `string` | — | ✅ |
| `allowed_ssh_cidrs` | CIDRs allowed SSH access — empty = no SSH | `list(string)` | `[]` | ❌ |
| `allowed_http_cidrs` | CIDRs allowed HTTP access | `list(string)` | `["0.0.0.0/0"]` | ❌ |
| `allowed_https_cidrs` | CIDRs allowed HTTPS access | `list(string)` | `["0.0.0.0/0"]` | ❌ |
| `rds_port` | RDS port: 3306 (MySQL) or 5432 (PostgreSQL) | `number` | `5432` | ❌ |
| `additional_tags` | Extra tags merged with standard tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `web_security_group_id` | Web/app SG ID — pass to ec2 module |
| `database_security_group_id` | Database SG ID — pass to rds module |
| `internal_security_group_id` | Internal SG ID — for VPC-internal services |
| `web_security_group_name` | Web/app SG name |
| `database_security_group_name` | Database SG name |

---

## Security Notes

- SSH from `0.0.0.0/0` is blocked by a validation rule — this is intentional and cannot be overridden
- The database SG only allows traffic from the web SG — not from any CIDR directly
- The internal SG is isolated to VPC CIDR — nothing from the internet can reach it
- All security groups use `create_before_destroy` to prevent outages during updates

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-security-groups-v1.0.0`
