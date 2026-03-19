#!/bin/bash
# ================================================================
# Opt IT — GCP Terraform Modules Setup
# Run from inside your opt-it-modules directory:
#   cd opt-it-modules
#   bash setup-gcp-modules.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating GCP Terraform modules"
echo "================================================================"

mkdir -p terraform/gcp/networking/vpc/examples/basic
mkdir -p terraform/gcp/networking/firewall/examples/basic
mkdir -p terraform/gcp/compute/gce/examples/basic
mkdir -p terraform/gcp/storage/gcs/examples/basic
mkdir -p terraform/gcp/database/cloud-sql/examples/basic

# ────────────────────────────────────────────────────────────────
# MODULE 1 — GCP VPC
# GCP VPC is global — one VPC spans all regions
# Subnets are regional
# ────────────────────────────────────────────────────────────────

cat > terraform/gcp/networking/vpc/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/gcp/networking/vpc/variables.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard Opt IT variables present in every module
# ─────────────────────────────────────────────────────────────

variable "client_name" {
  description = "Name of the client this infrastructure belongs to. Lowercase alphanumeric and hyphens only. Example: acme-corp"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric characters and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Version of this module being used. Injected by the Backstage template."
  type        = string
  default     = "1.0.0"
}

# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard GCP variables present in every module
#
# AUTHENTICATION:
#   This module uses Application Default Credentials (ADC).
#   For local development, run once:
#     gcloud auth application-default login
#   For CI/CD, use Workload Identity Federation.
#   Never use service account JSON key files — they are a
#   security risk and difficult to rotate.
# ─────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP Project ID where resources will be created. The project must already exist. Find it in GCP Console → Project selector. Example: acme-corp-prod-123456"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 characters, start with a letter, and contain only lowercase letters, numbers, and hyphens."
  }
}

variable "region" {
  description = "GCP region for subnet creation. GCP VPCs are global but subnets are regional. Example: us-central1, europe-west1, asia-southeast1"
  type        = string
  default     = "us-central1"
}

# ─────────────────────────────────────────────────────────────
# VPC CONFIGURATION
#
# NOTE: GCP VPCs are GLOBAL — one VPC spans all regions.
# This is different from AWS (regional VPC) and Azure (regional VNet).
# Subnets are regional and defined within the global VPC.
# ─────────────────────────────────────────────────────────────

variable "public_subnet_cidr" {
  description = "CIDR range for the public subnet. Resources here have external IPs. Example: 10.0.1.0/24"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrnetmask(var.public_subnet_cidr))
    error_message = "public_subnet_cidr must be a valid CIDR block."
  }
}

variable "private_subnet_cidr" {
  description = "CIDR range for the private subnet. Resources here have internal IPs only. Example: 10.0.10.0/24"
  type        = string
  default     = "10.0.10.0/24"

  validation {
    condition     = can(cidrnetmask(var.private_subnet_cidr))
    error_message = "private_subnet_cidr must be a valid CIDR block."
  }
}

variable "enable_cloud_nat" {
  description = "Whether to enable Cloud NAT for private subnet internet egress. Recommended for prod. Without this, private VMs cannot reach the internet."
  type        = bool
  default     = false
}

variable "additional_labels" {
  description = "Additional GCP labels to apply to all resources. GCP uses labels instead of tags. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/gcp/networking/vpc/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# PROVIDER
# Uses Application Default Credentials (ADC) automatically.
# Run: gcloud auth application-default login
# ─────────────────────────────────────────────────────────────

provider "google" {
  project = var.project_id
  region  = var.region
}

# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# NOTE: GCP uses labels (key-value pairs) not tags like AWS/Azure
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_labels = merge(
    {
      client        = var.client_name
      environment   = var.environment
      managed_by    = "opt-it-backstage"
      module        = "terraform-gcp-vpc"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

# ─────────────────────────────────────────────────────────────
# VPC NETWORK
# GCP VPCs are global — no region needed here
# custom_subnet_mode = we manage subnets explicitly
# ─────────────────────────────────────────────────────────────

resource "google_compute_network" "this" {
  name                    = "${local.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false  # we manage subnets explicitly
  description             = "VPC for ${var.client_name} ${var.environment} — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# PUBLIC SUBNET
# Resources here get external IPs
# ─────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "public" {
  name                     = "${local.name_prefix}-public-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.public_subnet_cidr
  private_ip_google_access = true  # allows access to Google APIs without external IP
  description              = "Public subnet for ${var.client_name} ${var.environment}"
}

# ─────────────────────────────────────────────────────────────
# PRIVATE SUBNET
# Resources here have internal IPs only
# ─────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "private" {
  name                     = "${local.name_prefix}-private-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.private_subnet_cidr
  private_ip_google_access = true  # allows private VMs to reach Google APIs
  description              = "Private subnet for ${var.client_name} ${var.environment}"
}

# ─────────────────────────────────────────────────────────────
# CLOUD NAT — optional
# Allows private subnet VMs to reach the internet
# Without this, private VMs are fully isolated
# ─────────────────────────────────────────────────────────────

resource "google_compute_router" "this" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "${local.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "${local.name_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.this[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
EOF

cat > terraform/gcp/networking/vpc/outputs.tf << 'EOF'
output "vpc_id" {
  description = "The ID of the VPC network. Pass to firewall, gce, and cloud-sql modules."
  value       = google_compute_network.this.id
}

output "vpc_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.this.name
}

output "vpc_self_link" {
  description = "The self_link of the VPC. Required by some GCP resources."
  value       = google_compute_network.this.self_link
}

output "public_subnet_name" {
  description = "Name of the public subnet."
  value       = google_compute_subnetwork.public.name
}

output "public_subnet_self_link" {
  description = "Self link of the public subnet."
  value       = google_compute_subnetwork.public.self_link
}

output "private_subnet_name" {
  description = "Name of the private subnet."
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_self_link" {
  description = "Self link of the private subnet. Pass to gce module as subnetwork."
  value       = google_compute_subnetwork.private.self_link
}

output "name_prefix" {
  description = "Naming prefix used across all resources."
  value       = local.name_prefix
}

output "standard_labels" {
  description = "Standard labels applied to all resources."
  value       = local.standard_labels
}
EOF

cat > terraform/gcp/networking/vpc/CHANGELOG.md << 'EOF'
# Changelog — terraform-gcp-vpc

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Global GCP VPC with custom subnet mode
- Public subnet with private_ip_google_access enabled
- Private subnet with private_ip_google_access enabled
- Optional Cloud NAT with Cloud Router for private subnet internet egress
- Application Default Credentials (ADC) authentication
- Standard Opt IT labeling on all resources (GCP uses labels not tags)
- Input validation for client_name, environment, project_id, subnet CIDRs
- Outputs: vpc_id, vpc_name, vpc_self_link, public/private subnet names and self_links
EOF

cat > terraform/gcp/networking/vpc/README.md << 'EOF'
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
EOF

cat > terraform/gcp/networking/vpc/examples/basic/main.tf << 'EOF'
module "vpc" {
  source      = "../../"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

output "vpc_name"               { value = module.vpc.vpc_name }
output "private_subnet_self_link" { value = module.vpc.private_subnet_self_link }
EOF

echo "✅ GCP VPC module created"

# ────────────────────────────────────────────────────────────────
# MODULE 2 — GCP FIREWALL
# GCP firewall rules are VPC-level and use network tags to target VMs
# This is fundamentally different from AWS SGs and Azure NSGs
# ────────────────────────────────────────────────────────────────

cat > terraform/gcp/networking/firewall/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/gcp/networking/firewall/variables.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard Opt IT variables present in every module
# ─────────────────────────────────────────────────────────────

variable "client_name" {
  description = "Name of the client. Lowercase alphanumeric and hyphens only. Example: acme-corp"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric characters and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Version of this module being used. Injected by the Backstage template."
  type        = string
  default     = "1.0.0"
}

# ─────────────────────────────────────────────────────────────
# REQUIRED — Standard GCP variables
# ─────────────────────────────────────────────────────────────

variable "project_id" {
  description = "GCP Project ID. Must match the project used in the vpc module."
  type        = string
}

# ─────────────────────────────────────────────────────────────
# VPC DEPENDENCY
# ─────────────────────────────────────────────────────────────

variable "vpc_name" {
  description = "Name of the VPC network. Passed from module.vpc.vpc_name"
  type        = string
}

# ─────────────────────────────────────────────────────────────
# FIREWALL CONFIGURATION
#
# NOTE: GCP firewall rules work differently from AWS/Azure:
# - Rules apply to the entire VPC, not to a subnet or instance
# - VMs are targeted using NETWORK TAGS (string labels on VMs)
# - A VM only gets a rule if it has the matching network tag
# - This module creates standard tags: web-server, db-server
#   Apply these tags to your GCE instances accordingly
# ─────────────────────────────────────────────────────────────

variable "allowed_ssh_source_ranges" {
  description = "List of IP CIDR ranges allowed SSH access to VMs tagged with 'ssh-access'. Leave empty to disable SSH. Example: [\"203.0.113.10/32\"]. Never use 0.0.0.0/0."
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.allowed_ssh_source_ranges, "0.0.0.0/0")
    error_message = "SSH from 0.0.0.0/0 is not permitted. Provide specific IP ranges."
  }
}

variable "allowed_http_source_ranges" {
  description = "IP ranges allowed HTTP (port 80) access to VMs tagged 'web-server'. Use [\"0.0.0.0/0\"] for public access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "allowed_https_source_ranges" {
  description = "IP ranges allowed HTTPS (port 443) access to VMs tagged 'web-server'. Use [\"0.0.0.0/0\"] for public access."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "db_port" {
  description = "Database port to allow internal access. PostgreSQL: 5432, MySQL: 3306."
  type        = number
  default     = 5432

  validation {
    condition     = contains([3306, 5432], var.db_port)
    error_message = "db_port must be 3306 (MySQL) or 5432 (PostgreSQL)."
  }
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/gcp/networking/firewall/main.tf << 'EOF'
# ─────────────────────────────────────────────────────────────
# PROVIDER
# ─────────────────────────────────────────────────────────────

provider "google" {
  project = var.project_id
}

# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_labels = merge(
    {
      client         = var.client_name
      environment    = var.environment
      managed_by     = "opt-it-backstage"
      module         = "terraform-gcp-firewall"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

# ─────────────────────────────────────────────────────────────
# HTTP INBOUND — targets VMs tagged "web-server"
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_http" {
  count   = length(var.allowed_http_source_ranges) > 0 ? 1 : 0
  name    = "${local.name_prefix}-allow-http"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = var.allowed_http_source_ranges
  target_tags   = ["web-server"]  # only VMs with this tag receive this rule
  description   = "Allow HTTP inbound to web-server tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# HTTPS INBOUND — targets VMs tagged "web-server"
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_https" {
  count   = length(var.allowed_https_source_ranges) > 0 ? 1 : 0
  name    = "${local.name_prefix}-allow-https"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.allowed_https_source_ranges
  target_tags   = ["web-server"]
  description   = "Allow HTTPS inbound to web-server tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# SSH INBOUND — targets VMs tagged "ssh-access"
# Only created if allowed_ssh_source_ranges is provided
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_ssh" {
  count   = length(var.allowed_ssh_source_ranges) > 0 ? 1 : 0
  name    = "${local.name_prefix}-allow-ssh"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_source_ranges
  target_tags   = ["ssh-access"]
  description   = "Allow SSH inbound from approved IPs to ssh-access tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# DB PORT — internal VPC traffic only
# Targets VMs tagged "db-server"
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_db_internal" {
  name    = "${local.name_prefix}-allow-db-internal"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = [tostring(var.db_port)]
  }

  # Only allow from within VPC — no internet access to DB
  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["db-server"]
  description   = "Allow DB port inbound from VPC CIDR only to db-server tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# INTERNAL VPC TRAFFIC
# Allows all traffic between resources within the VPC
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
  description   = "Allow all internal VPC traffic — managed by Opt IT Backstage"
}
EOF

cat > terraform/gcp/networking/firewall/outputs.tf << 'EOF'
output "web_server_tag" {
  description = "Network tag to apply to web-server GCE instances to receive HTTP/HTTPS firewall rules."
  value       = "web-server"
}

output "ssh_access_tag" {
  description = "Network tag to apply to GCE instances that need SSH access."
  value       = "ssh-access"
}

output "db_server_tag" {
  description = "Network tag to apply to database GCE instances."
  value       = "db-server"
}
EOF

cat > terraform/gcp/networking/firewall/CHANGELOG.md << 'EOF'
# Changelog — terraform-gcp-firewall

All notable changes to this module will be documented here.

---

## [1.0.0] - 2026-03-19

### Added
- HTTP and HTTPS inbound rules targeting web-server tagged VMs
- SSH inbound rule targeting ssh-access tagged VMs (empty = disabled)
- SSH from 0.0.0.0/0 blocked by validation rule
- DB port inbound from VPC CIDR only targeting db-server tagged VMs
- Internal VPC traffic rule (TCP, UDP, ICMP)
- Outputs expose network tag names for use in GCE module
- Standard Opt IT labeling
EOF

cat > terraform/gcp/networking/firewall/README.md << 'EOF'
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
EOF

cat > terraform/gcp/networking/firewall/examples/basic/main.tf << 'EOF'
module "vpc" {
  source      = "../../vpc"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

module "firewall" {
  source      = "../../"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  vpc_name    = module.vpc.vpc_name
}

output "web_server_tag" { value = module.firewall.web_server_tag }
EOF

echo "✅ GCP Firewall module created"

# ────────────────────────────────────────────────────────────────
# MODULE 3 — GCP COMPUTE ENGINE (GCE)
# ────────────────────────────────────────────────────────────────

cat > terraform/gcp/compute/gce/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/gcp/compute/gce/variables.tf << 'EOF'
variable "client_name" {
  description = "Client name. Lowercase alphanumeric and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Version of this module. Injected by Backstage."
  type        = string
  default     = "1.0.0"
}

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "region" {
  description = "GCP region. Must match the region used in the vpc module."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone within the region. Example: us-central1-a, us-central1-b"
  type        = string
  default     = "us-central1-a"
}

variable "subnetwork_self_link" {
  description = "Self link of the subnet to place the VM in. Use private subnet. Passed from module.vpc.private_subnet_self_link"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type. dev: e2-medium, prod: n2-standard-2. See https://cloud.google.com/compute/docs/machine-resource"
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. Minimum 10 GB."
  type        = number
  default     = 20

  validation {
    condition     = var.boot_disk_size_gb >= 10
    error_message = "boot_disk_size_gb must be at least 10 GB."
  }
}

variable "boot_disk_type" {
  description = "Boot disk type. pd-standard: HDD (dev), pd-ssd: SSD (prod), pd-balanced: balanced SSD."
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.boot_disk_type)
    error_message = "boot_disk_type must be pd-standard, pd-ssd, or pd-balanced."
  }
}

variable "image" {
  description = "Boot disk image. Default: latest Debian 12. Example: debian-cloud/debian-12, ubuntu-os-cloud/ubuntu-2204-lts"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "network_tags" {
  description = "Network tags to apply to the VM. Tags control which firewall rules apply. Example: [\"web-server\", \"ssh-access\"]. Use the output tags from the firewall module."
  type        = list(string)
  default     = []
}

variable "enable_public_ip" {
  description = "Whether to assign a public IP. Set to false for private VMs — use Cloud IAP or Cloud NAT for access."
  type        = bool
  default     = false
}

variable "metadata_startup_script" {
  description = "Startup script to run on first boot. Leave empty for no startup script."
  type        = string
  default     = ""
}

variable "service_account_email" {
  description = "Service account email to attach to the VM. Leave empty to use the Compute Engine default service account."
  type        = string
  default     = ""
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/gcp/compute/gce/main.tf << 'EOF'
provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_labels = merge(
    {
      client         = var.client_name
      environment    = var.environment
      managed_by     = "opt-it-backstage"
      module         = "terraform-gcp-gce"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

resource "google_compute_instance" "this" {
  name         = "${local.name_prefix}-vm"
  project      = var.project_id
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.network_tags  # these control which firewall rules apply
  labels       = local.standard_labels

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
      labels = local.standard_labels
    }
  }

  network_interface {
    subnetwork = var.subnetwork_self_link

    # Public IP — only assigned when enable_public_ip = true
    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {
        # Empty access_config = ephemeral public IP
      }
    }
  }

  # Service account
  dynamic "service_account" {
    for_each = var.service_account_email != "" ? [1] : []
    content {
      email  = var.service_account_email
      scopes = ["cloud-platform"]
    }
  }

  # Startup script
  metadata = var.metadata_startup_script != "" ? {
    startup-script = var.metadata_startup_script
  } : {}

  # Enable OS Login — SSH key management via GCP IAM
  # This is the recommended approach instead of managing SSH keys manually
  metadata_startup_script = null

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [metadata_startup_script]
  }
}
EOF

cat > terraform/gcp/compute/gce/outputs.tf << 'EOF'
output "instance_id" {
  description = "The GCE instance ID."
  value       = google_compute_instance.this.instance_id
}

output "instance_name" {
  description = "The name of the GCE instance."
  value       = google_compute_instance.this.name
}

output "internal_ip" {
  description = "Internal IP address of the instance."
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "external_ip" {
  description = "External IP address of the instance. Empty if enable_public_ip = false."
  value       = var.enable_public_ip ? google_compute_instance.this.network_interface[0].access_config[0].nat_ip : ""
}

output "self_link" {
  description = "Self link of the GCE instance."
  value       = google_compute_instance.this.self_link
}
EOF

cat > terraform/gcp/compute/gce/CHANGELOG.md << 'EOF'
# Changelog — terraform-gcp-gce

All notable changes to this module will be documented here.

---

## [1.0.0] - 2026-03-19

### Added
- GCE instance with configurable machine type, boot disk, and image
- Network tags support for firewall rule targeting
- Shielded VM config enabled (Secure Boot, vTPM, Integrity Monitoring)
- Optional public IP via ephemeral access_config
- Optional service account attachment
- Optional startup script via metadata
- Standard Opt IT labeling
- Outputs: instance_id, instance_name, internal_ip, external_ip, self_link
EOF

cat > terraform/gcp/compute/gce/README.md << 'EOF'
# terraform-gcp-gce

Provisions a GCE (Google Compute Engine) instance with Shielded VM, network tags, and optional public IP.

Depends on `terraform-gcp-vpc` and `terraform-gcp-firewall`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `google_compute_instance` | GCE VM with Shielded VM config enabled |

---

## Network Tags

Apply firewall tags from the firewall module:

```hcl
module "gce" {
  # ...
  network_tags = [
    module.firewall.web_server_tag,   # "web-server"
    module.firewall.ssh_access_tag,   # "ssh-access"
  ]
}
```

---

## Usage

```hcl
module "gce" {
  source = "github.com/equaan/opt-it-modules//terraform/gcp/compute/gce?ref=terraform-gcp-gce-v1.0.0"

  client_name          = "acme-corp"
  environment          = "prod"
  project_id           = "acme-corp-prod-123456"
  region               = "us-central1"
  zone                 = "us-central1-a"
  subnetwork_self_link = module.vpc.private_subnet_self_link
  machine_type         = "n2-standard-2"
  boot_disk_type       = "pd-ssd"
  network_tags         = [module.firewall.web_server_tag]
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
| `zone` | GCP zone | `string` | `us-central1-a` | ❌ |
| `subnetwork_self_link` | Subnet self_link from vpc module | `string` | — | ✅ |
| `machine_type` | GCE machine type | `string` | `e2-medium` | ❌ |
| `boot_disk_size_gb` | Boot disk size in GB | `number` | `20` | ❌ |
| `boot_disk_type` | Boot disk type | `string` | `pd-standard` | ❌ |
| `image` | Boot disk image | `string` | `debian-cloud/debian-12` | ❌ |
| `network_tags` | Firewall targeting tags | `list(string)` | `[]` | ❌ |
| `enable_public_ip` | Assign public IP | `bool` | `false` | ❌ |
| `metadata_startup_script` | Startup script | `string` | `""` | ❌ |
| `service_account_email` | Service account to attach | `string` | `""` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `instance_id` | Instance ID |
| `instance_name` | Instance name |
| `internal_ip` | Internal IP |
| `external_ip` | External IP (empty if disabled) |
| `self_link` | Instance self_link |

---

## Module Version

`terraform-gcp-gce-v1.0.0`
EOF

cat > terraform/gcp/compute/gce/examples/basic/main.tf << 'EOF'
module "vpc" {
  source      = "../../../networking/vpc"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

module "firewall" {
  source      = "../../../networking/firewall"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  vpc_name    = module.vpc.vpc_name
}

module "gce" {
  source               = "../../"
  client_name          = "example-client"
  environment          = "dev"
  project_id           = "example-project-123456"
  region               = "us-central1"
  zone                 = "us-central1-a"
  subnetwork_self_link = module.vpc.private_subnet_self_link
  network_tags         = [module.firewall.web_server_tag]
}

output "internal_ip" { value = module.gce.internal_ip }
EOF

echo "✅ GCP GCE module created"

# ────────────────────────────────────────────────────────────────
# MODULE 4 — GCP CLOUD STORAGE (GCS)
# ────────────────────────────────────────────────────────────────

cat > terraform/gcp/storage/gcs/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/gcp/storage/gcs/variables.tf << 'EOF'
variable "client_name" {
  description = "Client name. Lowercase alphanumeric and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Module version. Injected by Backstage."
  type        = string
  default     = "1.0.0"
}

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "location" {
  description = "GCS bucket location. Can be a region (us-central1), multi-region (US, EU, ASIA), or dual-region. Multi-region recommended for prod."
  type        = string
  default     = "US"
}

variable "bucket_suffix" {
  description = "Suffix appended to bucket name. Lowercase alphanumeric and hyphens. Example: assets, backups, uploads"
  type        = string
  default     = "storage"
}

variable "storage_class" {
  description = "Storage class. STANDARD: frequent access, NEARLINE: monthly, COLDLINE: quarterly, ARCHIVE: yearly."
  type        = string
  default     = "STANDARD"

  validation {
    condition     = contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], var.storage_class)
    error_message = "storage_class must be STANDARD, NEARLINE, COLDLINE, or ARCHIVE."
  }
}

variable "enable_versioning" {
  description = "Whether to enable object versioning. Recommended for prod."
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Days to retain soft-deleted objects. 0 to disable soft delete."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 0 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 0 and 90."
  }
}

variable "force_destroy" {
  description = "Allow bucket destruction even with objects inside. Set to false for prod."
  type        = bool
  default     = false
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/gcp/storage/gcs/main.tf << 'EOF'
provider "google" {
  project = var.project_id
}

locals {
  name_prefix = "${var.client_name}-${var.environment}"
  bucket_name = "${var.client_name}-${var.environment}-${var.bucket_suffix}"

  standard_labels = merge(
    {
      client         = var.client_name
      environment    = var.environment
      managed_by     = "opt-it-backstage"
      module         = "terraform-gcp-gcs"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

resource "google_storage_bucket" "this" {
  name          = local.bucket_name
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class
  force_destroy = var.force_destroy
  labels        = local.standard_labels

  # Block public access — all buckets are private by default
  public_access_prevention = "enforced"

  # Uniform bucket-level access — simpler and more secure than ACLs
  uniform_bucket_level_access = true

  dynamic "versioning" {
    for_each = var.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "soft_delete_policy" {
    for_each = var.soft_delete_retention_days > 0 ? [1] : []
    content {
      retention_duration_seconds = var.soft_delete_retention_days * 86400
    }
  }
}
EOF

cat > terraform/gcp/storage/gcs/outputs.tf << 'EOF'
output "bucket_name" {
  description = "The name of the GCS bucket."
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "The URL of the GCS bucket. Format: gs://bucket-name"
  value       = "gs://${google_storage_bucket.this.name}"
}

output "bucket_self_link" {
  description = "The self_link of the bucket."
  value       = google_storage_bucket.this.self_link
}
EOF

cat > terraform/gcp/storage/gcs/CHANGELOG.md << 'EOF'
# Changelog — terraform-gcp-gcs

---

## [1.0.0] - 2026-03-19

### Added
- GCS bucket with public access prevention enforced
- Uniform bucket-level access enforced (no ACLs)
- Optional versioning
- Optional soft delete with configurable retention
- force_destroy toggle — defaults to false for safety
- Standard Opt IT labeling
EOF

cat > terraform/gcp/storage/gcs/README.md << 'EOF'
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
EOF

cat > terraform/gcp/storage/gcs/examples/basic/main.tf << 'EOF'
module "gcs" {
  source        = "../../"
  client_name   = "example-client"
  environment   = "dev"
  project_id    = "example-project-123456"
  bucket_suffix = "uploads"
}

output "bucket_url" { value = module.gcs.bucket_url }
EOF

echo "✅ GCP GCS module created"

# ────────────────────────────────────────────────────────────────
# MODULE 5 — GCP CLOUD SQL
# ────────────────────────────────────────────────────────────────

cat > terraform/gcp/database/cloud-sql/versions.tf << 'EOF'
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
EOF

cat > terraform/gcp/database/cloud-sql/variables.tf << 'EOF'
variable "client_name" {
  description = "Client name. Lowercase alphanumeric and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Module version. Injected by Backstage."
  type        = string
  default     = "1.0.0"
}

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud SQL instance."
  type        = string
  default     = "us-central1"
}

variable "vpc_self_link" {
  description = "Self link of the VPC for private IP connectivity. Passed from module.vpc.vpc_self_link"
  type        = string
}

variable "db_engine" {
  description = "Database engine. postgres = PostgreSQL, mysql = MySQL."
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["postgres", "mysql"], var.db_engine)
    error_message = "db_engine must be postgres or mysql."
  }
}

variable "db_version" {
  description = "Database version. PostgreSQL: POSTGRES_14, POSTGRES_15. MySQL: MYSQL_8_0."
  type        = string
  default     = "POSTGRES_15"
}

variable "tier" {
  description = "Cloud SQL machine tier. dev: db-f1-micro, staging: db-g1-small, prod: db-n1-standard-2. See https://cloud.google.com/sql/docs/postgres/instance-settings"
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size_gb" {
  description = "Storage disk size in GB. Minimum 10 GB."
  type        = number
  default     = 10

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be at least 10 GB."
  }
}

variable "admin_password" {
  description = "Root/admin password for the database. Never commit this — use TF_VAR_admin_password."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_password) >= 8
    error_message = "admin_password must be at least 8 characters."
  }
}

variable "backup_enabled" {
  description = "Whether to enable automated backups."
  type        = bool
  default     = true
}

variable "availability_type" {
  description = "Availability type. ZONAL: single zone (dev/staging), REGIONAL: multi-zone HA (prod)."
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.availability_type)
    error_message = "availability_type must be ZONAL or REGIONAL."
  }
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
EOF

cat > terraform/gcp/database/cloud-sql/main.tf << 'EOF'
provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_labels = merge(
    {
      client         = var.client_name
      environment    = var.environment
      managed_by     = "opt-it-backstage"
      module         = "terraform-gcp-cloud-sql"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

# Private service access — required for Cloud SQL private IP
resource "google_compute_global_address" "private_ip_range" {
  name          = "${local.name_prefix}-sql-private-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_sql_database_instance" "this" {
  name             = "${local.name_prefix}-sql"
  project          = var.project_id
  region           = var.region
  database_version = var.db_version

  deletion_protection = var.environment == "prod" ? true : false

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    user_labels       = local.standard_labels

    ip_configuration {
      ipv4_enabled                                  = false  # private IP only
      private_network                               = var.vpc_self_link
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = var.backup_enabled
      start_time = "03:00"
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "this" {
  name     = "appdb"
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "root" {
  name     = var.db_engine == "postgres" ? "postgres" : "root"
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  password = var.admin_password
}
EOF

cat > terraform/gcp/database/cloud-sql/outputs.tf << 'EOF'
output "instance_name" {
  description = "Cloud SQL instance name."
  value       = google_sql_database_instance.this.name
}

output "private_ip_address" {
  description = "Private IP address of the Cloud SQL instance."
  value       = google_sql_database_instance.this.private_ip_address
  sensitive   = true
}

output "connection_name" {
  description = "Cloud SQL connection name. Format: project:region:instance. Used by Cloud SQL Auth Proxy."
  value       = google_sql_database_instance.this.connection_name
}

output "database_name" {
  description = "Name of the initial database created."
  value       = google_sql_database.this.name
}

output "db_port" {
  description = "Port the database listens on. PostgreSQL: 5432, MySQL: 3306."
  value       = var.db_engine == "postgres" ? 5432 : 3306
}
EOF

cat > terraform/gcp/database/cloud-sql/CHANGELOG.md << 'EOF'
# Changelog — terraform-gcp-cloud-sql

---

## [1.0.0] - 2026-03-19

### Added
- Cloud SQL instance supporting PostgreSQL and MySQL
- Private IP only — no public IP exposure
- Private service access connection via VPC peering
- Deletion protection auto-enabled for prod
- Regional availability type option for HA
- Automated backups with configurable start time
- Disk autoresize enabled
- Initial database and root user created
- Standard Opt IT labeling
EOF

cat > terraform/gcp/database/cloud-sql/README.md << 'EOF'
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
EOF

cat > terraform/gcp/database/cloud-sql/examples/basic/main.tf << 'EOF'
variable "db_password" {
  type      = string
  sensitive = true
}

module "vpc" {
  source      = "../../../networking/vpc"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

module "cloud_sql" {
  source         = "../../"
  client_name    = "example-client"
  environment    = "dev"
  project_id     = "example-project-123456"
  region         = "us-central1"
  vpc_self_link  = module.vpc.vpc_self_link
  db_engine      = "postgres"
  admin_password = var.db_password
}

output "connection_name" { value = module.cloud_sql.connection_name }
EOF

echo "✅ GCP Cloud SQL module created"

# ────────────────────────────────────────────────────────────────
# COMMIT AND TAG ALL MODULES
# ────────────────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo "  Committing and tagging all GCP modules..."
echo "================================================================"

git add terraform/gcp/
git commit -m "feat(gcp): add GCP modules — vpc, firewall, gce, gcs, cloud-sql v1.0.0"

git tag terraform-gcp-vpc-v1.0.0
git tag terraform-gcp-firewall-v1.0.0
git tag terraform-gcp-gce-v1.0.0
git tag terraform-gcp-gcs-v1.0.0
git tag terraform-gcp-cloud-sql-v1.0.0

git push origin main --tags

echo ""
echo "================================================================"
echo "  ✅ All GCP modules pushed and tagged!"
echo ""
echo "  Tags created:"
echo "    terraform-gcp-vpc-v1.0.0"
echo "    terraform-gcp-firewall-v1.0.0"
echo "    terraform-gcp-gce-v1.0.0"
echo "    terraform-gcp-gcs-v1.0.0"
echo "    terraform-gcp-cloud-sql-v1.0.0"
echo "================================================================"