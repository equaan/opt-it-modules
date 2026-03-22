# opt-it-modules

> Versioned Infrastructure as Code modules for Opt IT Technologies client environments.

This repository is the **single source of truth** for all reusable infrastructure modules used by Opt IT. Every module in this repo is production-grade, independently versioned, and consumed by Backstage templates in `opt-it-catalog`.

---

## Table of Contents

- [Repository Structure](#repository-structure)
- [How It Works](#how-it-works)
- [Module Standards](#module-standards)
- [Adding a New Module](#adding-a-new-module)
- [Versioning Guide](#versioning-guide)
- [Current Module Versions](#current-module-versions)
- [Standard Tags](#standard-tags)
- [Testing a Module Locally](#testing-a-module-locally)
- [Common Mistakes To Avoid](#common-mistakes-to-avoid)

---

## Repository Structure

```
opt-it-modules/
│
├── terraform/
│   ├── aws/
│   │   ├── networking/
│   │   │   ├── vpc/                    ← VPC + IGW + NAT Gateway
│   │   │   ├── subnets/                ← Public + private subnets + route tables
│   │   │   └── security-groups/        ← Web, database, internal SGs
│   │   ├── compute/
│   │   │   ├── ec2/                    ← EC2 instance + EBS volume
│   │   │   └── eks/                    ← (Phase 2)
│   │   ├── storage/
│   │   │   └── s3/                     ← S3 bucket + encryption + versioning
│   │   ├── database/
│   │   │   └── rds/                    ← RDS instance (MySQL / PostgreSQL)
│   │   └── iam/
│   │       └── baseline/               ← EC2 role + instance profile + SSM + CW
│   ├── azure/                          ← Phase 2
│   └── gcp/                            ← Phase 2
│
├── cloudformation/
│   └── aws/
│       ├── base/
│       ├── networking/vpc/
│       ├── compute/ec2/
│       ├── storage/s3/
│       └── database/rds/
│
├── ansible/
│   └── aws/                            ← Ansible playbooks for AWS
│
├── cicd/
│   ├── github-actions/workflows/       ← build.yml, test.yml, deploy.yml
│   └── jenkins/                        ← Jenkinsfile
│
├── observability/                      ← Phase 3
└── security/                           ← Phase 4
```

---

## How It Works

```
DevOps engineer runs Backstage template
        ↓
Backstage fetches modules from this repo (pinned to git tags)
        ↓
Modules are copied into the client's repository
        ↓
A root main.tf is generated that wires all selected modules together
        ↓
PR is opened on the client's repo
        ↓
Client runs terraform init && terraform apply
```

Backstage templates live in `opt-it-catalog`. This repo only contains the modules themselves — no Backstage YAML lives here.

---

## Module Standards

Every module in this repo **must** follow these standards without exception. If a module is missing any of these, it is not ready for use.

### Required Files

```
module-name/
├── main.tf           ← AWS resources
├── variables.tf      ← all inputs, every variable documented
├── outputs.tf        ← all outputs, every output documented
├── versions.tf       ← Terraform + provider version pins
├── CHANGELOG.md      ← version history
├── README.md         ← usage, inputs, outputs, notes
└── examples/
    └── basic/
        └── main.tf   ← working example
```

### Required Variables

Every module must have these three standard variables in `variables.tf`:

```hcl
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
  description = "Version of this module. Injected by Backstage."
  type        = string
  default     = "1.0.0"
}
```

### Required Tags

Every AWS resource must have these tags:

```hcl
locals {
  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-{module-name}"
    },
    var.additional_tags
  )
}
```

Apply to every resource:
```hcl
resource "aws_vpc" "this" {
  # ...
  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}
```

### Variable Documentation Rules

Every variable must have:
- A `description` that explains what it does and gives an example
- A `type`
- A `default` where appropriate
- A `validation` block for any variable where bad input would cause a confusing error

```hcl
# ✅ Correct
variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a valid IPv4 CIDR. Example: 10.0.0.0/16"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

# ❌ Wrong — never do this
variable "vpc_cidr" {}
```

### Naming Convention

All resources follow this pattern:
```
{client_name}-{environment}-{resource-type}

Examples:
  acme-corp-prod-vpc
  acme-corp-prod-ec2
  acme-corp-staging-rds-subnet-group
```

This is enforced via the `name_prefix` local:
```hcl
locals {
  name_prefix = "${var.client_name}-${var.environment}"
}
```

---

## Adding a New Module

Follow these steps in order. Do not skip any step.

### Step 1 — Create the folder structure

```bash
mkdir -p terraform/aws/{category}/{module-name}/examples/basic
```

Example for an EKS module:
```bash
mkdir -p terraform/aws/compute/eks/examples/basic
```

### Step 2 — Write the files

Write all 6 required files. Start with `variables.tf` — if you can't define the inputs cleanly, the module design isn't clear enough yet.

Order to write them:
1. `variables.tf` — what goes in
2. `main.tf` — the resources
3. `outputs.tf` — what comes out
4. `versions.tf` — copy from any existing module, same for all
5. `examples/basic/main.tf` — a working example
6. `CHANGELOG.md` — document what v1.0.0 includes
7. `README.md` — usage, inputs table, outputs table, notes

### Step 3 — Follow the module standards

Check before committing:
- [ ] All 3 standard variables present (`client_name`, `environment`, `module_version`)
- [ ] Standard tags applied to every resource
- [ ] Every variable has a description with an example
- [ ] Sensitive variables marked with `sensitive = true`
- [ ] Validation blocks on critical variables
- [ ] `examples/basic/main.tf` actually works
- [ ] README has inputs and outputs tables

### Step 4 — Commit with a clear message

```bash
git add terraform/aws/compute/eks/
git commit -m "feat(eks): add terraform-aws-eks v1.0.0"
```

### Step 5 — Tag the module

```bash
git tag terraform-aws-eks-v1.0.0
git push origin main --tags
```

### Step 6 — Add a fetch step in opt-it-catalog

Open `opt-it-catalog/templates/aws-infrastructure/template.yaml` and add:
1. A fetch step for the new module
2. A conditional block in `skeleton/terraform/main.tf`
3. Any new variables in `skeleton/terraform/variables.tf`
4. Update the README module versions table

---

## Versioning Guide

### Semantic Versioning Rules

| Change | Version bump | Example |
|---|---|---|
| First stable release | `v1.0.0` | New module |
| New optional variable added | Minor `v1.1.0` | Added `enable_monitoring` with a default |
| New optional resource added | Minor `v1.1.0` | Added optional CloudWatch alarm |
| Required variable added | Major `v2.0.0` | Breaking — callers must update |
| Variable renamed or removed | Major `v2.0.0` | Breaking — callers must update |
| Default value changed | Major `v2.0.0` | Breaking — behaviour changes |
| Bug fix, no interface change | Patch `v1.0.1` | Fixed incorrect CIDR validation |

### Git Tag Format

```
terraform-aws-{module-name}-v{major}.{minor}.{patch}

Examples:
  terraform-aws-vpc-v1.0.0
  terraform-aws-ec2-v1.2.0
  terraform-aws-rds-v2.0.0
```

### Updating a Module Version

```bash
# Make your changes
git add .
git commit -m "feat(vpc): add support for IPv6 CIDR blocks"

# Tag the new version
git tag terraform-aws-vpc-v1.1.0
git push origin main --tags

# Update CHANGELOG.md
# Update the module versions table in opt-it-catalog README
# Update the fetch step URL in template.yaml if upgrading a pinned version
```

### Rule: Templates Always Pin To A Specific Tag

In `template.yaml`, module URLs always reference a specific tag — never `main`:

```yaml
# ✅ Correct — pinned to a specific version
url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-vpc-v1.0.0/terraform/aws/networking/vpc

# ❌ Wrong — main changes unpredictably
url: https://github.com/equaan/opt-it-modules/tree/main/terraform/aws/networking/vpc
```

---

## Current Module Versions

### Terraform — AWS

| Module | Path | Version | Tag |
|---|---|---|---|
| VPC | `terraform/aws/networking/vpc` | `v1.0.0` | `terraform-aws-vpc-v1.0.0` |
| Subnets | `terraform/aws/networking/subnets` | `v1.0.0` | `terraform-aws-subnets-v1.0.0` |
| Security Groups | `terraform/aws/networking/security-groups` | `v1.0.0` | `terraform-aws-security-groups-v1.0.0` |
| EC2 | `terraform/aws/compute/ec2` | `v1.0.0` | `terraform-aws-ec2-v1.0.0` |
| S3 | `terraform/aws/storage/s3` | `v1.0.0` | `terraform-aws-s3-v1.0.0` |
| RDS | `terraform/aws/database/rds` | `v1.0.0` | `terraform-aws-rds-v1.0.0` |
| IAM Baseline | `terraform/aws/iam/baseline` | `v1.0.0` | `terraform-aws-iam-baseline-v1.0.0` |

### Terraform — Azure

| Module | Path | Version | Tag |
|---|---|---|---|
| Resource Group | `terraform/azure/base/resource-group` | `v1.0.0` | `terraform-azure-resource-group-v1.0.0` |
| VNet | `terraform/azure/networking/vnet` | `v1.0.0` | `terraform-azure-vnet-v1.0.0` |
| NSG | `terraform/azure/networking/nsg` | `v1.0.0` | `terraform-azure-nsg-v1.0.0` |
| VM | `terraform/azure/compute/vm` | `v1.0.0` | `terraform-azure-vm-v1.0.0` |
| Blob Storage | `terraform/azure/storage/blob` | `v1.0.0` | `terraform-azure-blob-storage-v1.0.0` |
| SQL Flexible | `terraform/azure/database/sql-flexible` | `v1.0.0` | `terraform-azure-sql-flexible-v1.0.0` |

### Terraform — GCP

| Module | Path | Version | Tag |
|---|---|---|---|
| VPC | `terraform/GCP/networking/vpc` | `v1.0.0` | `terraform-gcp-vpc-v1.0.0` |
| Firewall | `terraform/GCP/networking/firewall` | `v1.0.0` | `terraform-gcp-firewall-v1.0.0` |
| GCE | `terraform/GCP/compute/gce` | `v1.0.0` | `terraform-gcp-gce-v1.0.0` |
| GCS | `terraform/GCP/storage/gcs` | `v1.0.0` | `terraform-gcp-gcs-v1.0.0` |
| Cloud SQL | `terraform/GCP/database/cloud-sql` | `v1.0.0` | `terraform-gcp-cloud-sql-v1.0.0` |

---

## Standard Tags

Every AWS resource created by any module in this repo will have these tags:

| Tag | Value | Purpose |
|---|---|---|
| `Client` | e.g. `acme-corp` | Which client owns this resource |
| `Environment` | `dev` / `staging` / `prod` | Which environment |
| `ManagedBy` | `opt-it-backstage` | How it was provisioned |
| `ModuleVersion` | e.g. `1.0.0` | Which module version was used |
| `ProvisionedBy` | `terraform` | IaC tool used |
| `Module` | e.g. `terraform-aws-vpc` | Which module created it |

These tags are mandatory. They allow Opt IT to answer questions like:
- Which resources belong to which client?
- Which resources were provisioned with an old module version?
- Which resources does Opt IT manage vs client-managed?

---

## Testing a Module Locally

Before tagging a module, test it locally:

```bash
cd terraform/aws/networking/vpc/examples/basic

# Initialise with the module source
terraform init

# Check the plan — no AWS credentials needed for plan validation
terraform plan

# If you have AWS credentials configured, apply to a test account
terraform apply

# Always destroy test resources after
terraform destroy
```

---

## Common Mistakes To Avoid

**Pointing templates to `main` instead of a tag**
Changes to `main` immediately affect all new client onboardings. Always tag before using in a template.

**Missing `additional_tags` variable**
Every module must accept `additional_tags = map(string)` so callers can add their own tags without forking the module.

**Hardcoding AWS region**
Never hardcode a region inside a module. Always accept it as `var.aws_region`. The provider is configured at the root level.

**Using `count` for optional resources instead of `for_each`**
`count` causes index shifting issues when the list changes. Use `for_each` for collections and `count = condition ? 1 : 0` only for truly optional single resources.

**No `prevent_destroy` on production-critical resources**
RDS instances, S3 buckets with data, and VPCs should have `lifecycle { prevent_destroy = true }` in prod to prevent accidental deletion.

**Exposing sensitive outputs without marking them sensitive**
RDS endpoints, passwords, and private IPs should be marked `sensitive = true` in `outputs.tf` to prevent them appearing in logs.

---

## Phase Roadmap

| Phase | Status | Scope |
|---|---|---|
| Phase 1 | ✅ Complete | AWS Terraform modules (VPC, Subnets, SGs, EC2, S3, RDS, IAM) |
| Phase 2 | ✅ Complete | Azure Terraform modules (Resource Group, VNet, NSG, VM, Blob, SQL Flexible) |
| Phase 2b | ✅ Complete | GCP Terraform modules + GcpResourcePicker + gcp-infrastructure template |
| Phase 3 | ✅ Complete | CI/CD modules (GitHub Actions, Jenkins, GitLab CI, ArgoCD) + Observability (Prometheus, Grafana, Alertmanager) |
| Phase 4 | 🔜 Planned | Security (Vault, SOPS, OPA) |
| Phase 5 | 🔜 Planned | Full onboarding wizard, drift detection, cost estimation |
