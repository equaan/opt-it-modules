# terraform-gcp-vpc

Provisions a global GCP VPC with public and private subnets and optional Cloud NAT.

**Key difference from AWS/Azure:** GCP VPCs are global — one VPC spans all regions. Subnets are regional. This module creates one VPC and two subnets in the specified region.

---

## Authentication

This module uses **Application Default Credentials (ADC)** — the GCP-recommended approach.

**Local development:**
```bash
gcloud auth application-default login
```

**CI/CD:** Use Workload Identity Federation — no JSON key files needed.

Never use service account JSON key files — they are difficult to rotate and a security risk if leaked.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `google_compute_network` | Global VPC with custom subnet mode |
| `google_compute_subnetwork` (public) | Public subnet in specified region |
| `google_compute_subnetwork` (private) | Private subnet in specified region |
| `google_compute_router` | Cloud Router for NAT (if enabled) |
| `google_compute_router_nat` | Cloud NAT for private subnet egress (if enabled) |

---

## Usage

```hcl
module "vpc" {
  source = "github.com/equaan/opt-it-modules//terraform/gcp/networking/vpc?ref=terraform-gcp-vpc-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"
  project_id  = "acme-corp-prod-123456"
  region      = "us-central1"

  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.10.0/24"
  enable_cloud_nat    = true
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `project_id` | GCP Project ID (must exist) | `string` | — | ✅ |
| `region` | GCP region for subnets | `string` | `us-central1` | ❌ |
| `module_version` | Module version | `string` | `1.0.0` | ❌ |
| `public_subnet_cidr` | Public subnet CIDR | `string` | `10.0.1.0/24` | ❌ |
| `private_subnet_cidr` | Private subnet CIDR | `string` | `10.0.10.0/24` | ❌ |
| `enable_cloud_nat` | Enable Cloud NAT for private egress | `bool` | `false` | ❌ |
| `additional_labels` | Extra GCP labels | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC network ID |
| `vpc_name` | VPC network name |
| `vpc_self_link` | VPC self_link — required by some GCP resources |
| `public_subnet_name` | Public subnet name |
| `public_subnet_self_link` | Public subnet self_link |
| `private_subnet_name` | Private subnet name |
| `private_subnet_self_link` | Private subnet self_link — pass to gce module |

---

## AWS/Azure Equivalent

| AWS | Azure | GCP |
|---|---|---|
| VPC (regional) | VNet (regional) | VPC (global) |
| Subnet | Subnet | Subnetwork |
| NAT Gateway | NAT Gateway | Cloud NAT + Cloud Router |
| Internet Gateway | Automatic | Automatic for public IPs |

---

## Module Version

`terraform-gcp-vpc-v1.0.0`
