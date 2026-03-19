# terraform-gcp-firewall

Provisions GCP Firewall Rules with network tag targeting for web, SSH, database, and internal traffic.

**Key difference from AWS/Azure:** GCP firewall rules are VPC-level and use **network tags** to target specific VMs. A VM only receives a firewall rule if it has the matching tag applied.

---

## Network Tags

This module creates rules targeting these tags. Apply them to your GCE instances:

| Tag | Rule applied | Use on |
|---|---|---|
| `web-server` | HTTP (80) + HTTPS (443) inbound | App/web VMs |
| `ssh-access` | SSH (22) inbound from allowed IPs | Any VM needing SSH |
| `db-server` | DB port inbound from VPC only | Database VMs |

**Example — applying tags in the GCE module:**
```hcl
module "gce" {
  # ...
  network_tags = ["web-server", "ssh-access"]
}
```

---

## Usage

```hcl
module "firewall" {
  source = "github.com/equaan/opt-it-modules//terraform/gcp/networking/firewall?ref=terraform-gcp-firewall-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"
  project_id  = "acme-corp-prod-123456"
  vpc_name    = module.vpc.vpc_name

  allowed_ssh_source_ranges = ["203.0.113.10/32"]
  db_port                   = 5432
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `project_id` | GCP Project ID | `string` | — | ✅ |
| `vpc_name` | VPC name from vpc module | `string` | — | ✅ |
| `allowed_ssh_source_ranges` | IPs allowed SSH — empty = disabled | `list(string)` | `[]` | ❌ |
| `allowed_http_source_ranges` | IPs allowed HTTP | `list(string)` | `["0.0.0.0/0"]` | ❌ |
| `allowed_https_source_ranges` | IPs allowed HTTPS | `list(string)` | `["0.0.0.0/0"]` | ❌ |
| `db_port` | Database port: 3306 or 5432 | `number` | `5432` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `web_server_tag` | Tag to apply to web VMs: `web-server` |
| `ssh_access_tag` | Tag to apply to VMs needing SSH: `ssh-access` |
| `db_server_tag` | Tag to apply to database VMs: `db-server` |

---

## AWS/Azure Equivalent

| AWS | Azure | GCP |
|---|---|---|
| Security Group (per instance) | NSG (per subnet) | Firewall Rule (per VPC, targeted by tag) |

---

## Module Version

`terraform-gcp-firewall-v1.0.0`
