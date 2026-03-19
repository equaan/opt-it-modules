#!/bin/bash
# ================================================================
# Opt IT — AWS Infrastructure Template Setup Script
# Run this from inside your opt-it-catalog directory:
#   cd opt-it-catalog
#   bash setup-aws-template.sh
# ================================================================

set -e

echo "================================================================"
echo "  Opt IT — Creating AWS Infrastructure Template"
echo "================================================================"

mkdir -p templates/aws-infrastructure/skeleton/terraform
mkdir -p templates/aws-infrastructure/skeleton/docs
mkdir -p docs

# ────────────────────────────────────────────────────────────────
# CATALOG-INFO.YAML
# Registers this template in the Backstage catalog
# ────────────────────────────────────────────────────────────────

cat > templates/aws-infrastructure/catalog-info.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: aws-infrastructure-template
  description: Opt IT AWS Infrastructure Template
spec:
  targets:
    - ./template.yaml
EOF

# ────────────────────────────────────────────────────────────────
# TEMPLATE.YAML
# The Backstage scaffolder template
# ────────────────────────────────────────────────────────────────

cat > templates/aws-infrastructure/template.yaml << 'EOF'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: aws-infrastructure
  title: AWS Infrastructure Setup
  description: Provisions production-grade AWS infrastructure for a client using versioned Opt IT modules. Supports Terraform and CloudFormation.
  tags:
    - aws
    - terraform
    - cloudformation
    - infrastructure
    - phase-1
spec:
  owner: devops
  type: infrastructure

  parameters:

    # ─────────────────────────────────────────
    # PAGE 1 — Client Information
    # ─────────────────────────────────────────
    - title: Step 1 - Client Information
      required:
        - client_name
        - environment
        - repoUrl
      properties:
        client_name:
          title: Client Name
          type: string
          description: "Lowercase alphanumeric and hyphens only. Example: acme-corp"
          ui:autofocus: true

        environment:
          title: Environment
          type: string
          enum:
            - dev
            - staging
            - prod
          enumNames:
            - Development
            - Staging
            - Production
          ui:widget: radio

        aws_region:
          title: AWS Region
          type: string
          default: us-east-1
          enum:
            - us-east-1
            - us-west-2
            - eu-west-1
            - ap-southeast-1
          enumNames:
            - US East (N. Virginia)
            - US West (Oregon)
            - EU West (Ireland)
            - AP Southeast (Singapore)

        repoUrl:
          title: Client Repository
          type: string
          ui:field: RepoUrlPicker
          ui:options:
            allowedHosts:
              - github.com

    # ─────────────────────────────────────────
    # PAGE 2 — IaC Tool Selection
    # ─────────────────────────────────────────
    - title: Step 2 - IaC Tool
      required:
        - iac_tool
      properties:
        iac_tool:
          title: Infrastructure as Code Tool
          type: string
          enum:
            - terraform
            - cloudformation
          enumNames:
            - Terraform
            - CloudFormation
          ui:widget: radio
          default: terraform

    # ─────────────────────────────────────────
    # PAGE 3 — AWS Resource Selection
    # Uses AwsResourcePicker custom field extension
    # ─────────────────────────────────────────
    - title: Step 3 - AWS Resources
      required:
        - iac_resources
      properties:
        iac_resources:
          title: AWS Resources
          type: object
          description: Select the AWS resources to provision and configure each one
          ui:field: AwsResourcePicker

    # ─────────────────────────────────────────
    # PAGE 4 — CI/CD Selection
    # ─────────────────────────────────────────
    - title: Step 4 - CI/CD Pipeline
      properties:
        setup_cicd:
          title: Set up CI/CD pipeline?
          type: boolean
          default: false
          ui:widget: radio

      dependencies:
        setup_cicd:
          oneOf:
            - properties:
                setup_cicd:
                  enum: [false]

            - properties:
                setup_cicd:
                  enum: [true]
                cicd_tool:
                  title: CI/CD Tool
                  type: string
                  enum: [github-actions, jenkins]
                  enumNames: [GitHub Actions, Jenkins]
                  default: github-actions
                github_actions_workflows:
                  title: Select Workflows
                  type: array
                  items:
                    type: string
                    enum: [build, test, deploy]
                    enumNames: [Build, Test, Deploy]
                  uniqueItems: true
                  ui:widget: checkboxes
              required:
                - cicd_tool

  # ─────────────────────────────────────────
  # STEPS
  # ─────────────────────────────────────────
  steps:

    # ── TERRAFORM ──────────────────────────

    - id: fetch-terraform-base
      name: Generate Terraform Base
      if: ${{ parameters.iac_tool === 'terraform' }}
      action: fetch:template
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/terraform/aws/networking/vpc
        targetPath: ./terraform/modules/vpc
        values:
          client_name:    ${{ parameters.client_name }}
          environment:    ${{ parameters.environment }}
          aws_region:     ${{ parameters.aws_region }}

    - id: fetch-terraform-vpc
      name: Fetch Terraform VPC Module
      if: ${{ parameters.iac_tool === 'terraform' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('vpc') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-vpc-v1.0.0/terraform/aws/networking/vpc
        targetPath: ./terraform/modules/vpc

    - id: fetch-terraform-subnets
      name: Fetch Terraform Subnets Module
      if: ${{ parameters.iac_tool === 'terraform' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('vpc') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-subnets-v1.0.0/terraform/aws/networking/subnets
        targetPath: ./terraform/modules/subnets

    - id: fetch-terraform-security-groups
      name: Fetch Terraform Security Groups Module
      if: ${{ parameters.iac_tool === 'terraform' and parameters.iac_resources.resources and (parameters.iac_resources.resources.includes('ec2') or parameters.iac_resources.resources.includes('rds')) }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-security-groups-v1.0.0/terraform/aws/networking/security-groups
        targetPath: ./terraform/modules/security-groups

    - id: fetch-terraform-ec2
      name: Fetch Terraform EC2 Module
      if: ${{ parameters.iac_tool === 'terraform' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('ec2') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-ec2-v1.0.0/terraform/aws/compute/ec2
        targetPath: ./terraform/modules/ec2

    - id: fetch-terraform-s3
      name: Fetch Terraform S3 Module
      if: ${{ parameters.iac_tool === 'terraform' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('s3') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-s3-v1.0.0/terraform/aws/storage/s3
        targetPath: ./terraform/modules/s3

    - id: fetch-terraform-rds
      name: Fetch Terraform RDS Module
      if: ${{ parameters.iac_tool === 'terraform' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('rds') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-rds-v1.0.0/terraform/aws/database/rds
        targetPath: ./terraform/modules/rds

    - id: fetch-terraform-iam
      name: Fetch Terraform IAM Baseline Module
      if: ${{ parameters.iac_tool === 'terraform' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('ec2') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/terraform-aws-iam-baseline-v1.0.0/terraform/aws/iam/baseline
        targetPath: ./terraform/modules/iam-baseline

    - id: generate-terraform-root
      name: Generate Terraform Root Configuration
      if: ${{ parameters.iac_tool === 'terraform' }}
      action: fetch:template
      input:
        url: https://github.com/equaan/opt-it-catalog/tree/main/templates/aws-infrastructure/skeleton/terraform
        targetPath: ./terraform
        values:
          client_name:         ${{ parameters.client_name }}
          environment:         ${{ parameters.environment }}
          aws_region:          ${{ parameters.aws_region }}
          provision_vpc:       ${{ parameters.iac_resources.resources and parameters.iac_resources.resources.includes('vpc') }}
          provision_ec2:       ${{ parameters.iac_resources.resources and parameters.iac_resources.resources.includes('ec2') }}
          provision_s3:        ${{ parameters.iac_resources.resources and parameters.iac_resources.resources.includes('s3') }}
          provision_rds:       ${{ parameters.iac_resources.resources and parameters.iac_resources.resources.includes('rds') }}
          vpc_cidr:            ${{ parameters.iac_resources.config.vpc_cidr }}
          ec2_instance_type:   ${{ parameters.iac_resources.config.ec2_instance_type }}
          s3_versioning:       ${{ parameters.iac_resources.config.s3_versioning }}
          rds_engine:          ${{ parameters.iac_resources.config.rds_engine }}

    # ── CLOUDFORMATION ─────────────────────

    - id: fetch-cfn-base
      name: Fetch CloudFormation Base
      if: ${{ parameters.iac_tool === 'cloudformation' }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/cloudformation/aws/base
        targetPath: ./cloudformation/base

    - id: fetch-cfn-vpc
      name: Fetch CloudFormation VPC
      if: ${{ parameters.iac_tool === 'cloudformation' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('vpc') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/cloudformation/aws/networking/vpc
        targetPath: ./cloudformation/vpc

    - id: fetch-cfn-ec2
      name: Fetch CloudFormation EC2
      if: ${{ parameters.iac_tool === 'cloudformation' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('ec2') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/cloudformation/aws/compute/ec2
        targetPath: ./cloudformation/ec2

    - id: fetch-cfn-s3
      name: Fetch CloudFormation S3
      if: ${{ parameters.iac_tool === 'cloudformation' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('s3') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/cloudformation/aws/storage/s3
        targetPath: ./cloudformation/s3

    - id: fetch-cfn-rds
      name: Fetch CloudFormation RDS
      if: ${{ parameters.iac_tool === 'cloudformation' and parameters.iac_resources.resources and parameters.iac_resources.resources.includes('rds') }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/cloudformation/aws/database/rds
        targetPath: ./cloudformation/rds

    # ── CI/CD ──────────────────────────────

    - id: fetch-github-actions
      name: Fetch GitHub Actions Workflows
      if: ${{ parameters.setup_cicd and parameters.cicd_tool === 'github-actions' }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/cicd/github-actions/workflows
        targetPath: ./.github/workflows

    - id: fetch-jenkins
      name: Fetch Jenkins Pipeline
      if: ${{ parameters.setup_cicd and parameters.cicd_tool === 'jenkins' }}
      action: fetch:plain
      input:
        url: https://github.com/equaan/opt-it-modules/tree/main/cicd/jenkins
        targetPath: ./cicd/jenkins

    # ── PUBLISH PR ─────────────────────────

    - id: publish-pr
      name: Open Pull Request on Client Repository
      action: publish:github:pull-request
      input:
        repoUrl: ${{ parameters.repoUrl }}
        branchName: infra/${{ parameters.client_name }}-${{ parameters.environment }}-${{ parameters.iac_resources.resources or parameters.cicd_tool or 'setup' }}
        targetBranchName: main
        update: true
        title: "feat(infra): provision AWS ${{ parameters.environment }} infrastructure for ${{ parameters.client_name }}"
        description: |
          ## AWS Infrastructure Onboarding 🚀

          Provisioned by **Opt IT Backstage** — do not edit these files manually.

          ### Configuration Summary

          | Field | Value |
          |---|---|
          | **Client** | ${{ parameters.client_name }} |
          | **Environment** | ${{ parameters.environment }} |
          | **AWS Region** | ${{ parameters.aws_region }} |
          | **IaC Tool** | ${{ parameters.iac_tool }} |
          | **Resources** | ${{ parameters.iac_resources.resources }} |
          | **CI/CD** | ${{ parameters.cicd_tool or 'none' }} |

          ### What Was Provisioned

          ```
          ${{ parameters.iac_resources.resources }}
          ```

          ### Next Steps

          1. Review all configuration values
          2. Add `TF_VAR_master_password` to GitHub Secrets (if RDS selected)
          3. Merge this PR
          4. Run `terraform init && terraform plan` from the `terraform/` directory
          5. Run `terraform apply` after plan is reviewed

          > ⚠️ Review all values before merging. Infrastructure changes are applied on merge.

  output:
    links:
      - title: View Pull Request
        url: ${{ steps['publish-pr'].output.remoteUrl }}
      - title: Client Repository
        url: https://github.com/${{ parameters.repoUrl }}
EOF

echo "✅ template.yaml created"

# ────────────────────────────────────────────────────────────────
# SKELETON — Root main.tf template
# This is the file that gets generated into the client repo
# It wires all the modules together based on what was selected
# ────────────────────────────────────────────────────────────────

cat > templates/aws-infrastructure/skeleton/terraform/main.tf << 'SKELEOF'
# ================================================================
# ${{ values.client_name }} — ${{ values.environment }} — AWS Infrastructure
# Generated by Opt IT Backstage on ${{ "" | now }}
# DO NOT EDIT MANUALLY — changes will be overwritten on next run
# ================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure backend for remote state:
  # backend "s3" {
  #   bucket = "${{ values.client_name }}-${{ values.environment }}-tfstate"
  #   key    = "infrastructure/terraform.tfstate"
  #   region = "${{ values.aws_region }}"
  # }
}

provider "aws" {
  region = var.aws_region
}

# ────────────────────────────────────────────────────────────────
# VPC
# ${% if values.provision_vpc %}Provisioned${% else %}Not selected${% endif %}
# ────────────────────────────────────────────────────────────────

${% if values.provision_vpc %}
module "vpc" {
  source = "./modules/vpc"

  client_name        = var.client_name
  environment        = var.environment
  module_version     = "1.0.0"
  aws_region         = var.aws_region
  vpc_cidr           = var.vpc_cidr
  enable_nat_gateway = var.environment == "prod" ? true : false
}

module "subnets" {
  source = "./modules/subnets"

  client_name         = var.client_name
  environment         = var.environment
  module_version      = "1.0.0"
  aws_region          = var.aws_region
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr
  internet_gateway_id = module.vpc.internet_gateway_id
  nat_gateway_id      = module.vpc.nat_gateway_id
}
${% endif %}

# ────────────────────────────────────────────────────────────────
# SECURITY GROUPS
# ${% if values.provision_ec2 or values.provision_rds %}Provisioned${% else %}Not selected${% endif %}
# ────────────────────────────────────────────────────────────────

${% if values.provision_ec2 or values.provision_rds %}
module "security_groups" {
  source = "./modules/security-groups"

  client_name    = var.client_name
  environment    = var.environment
  module_version = "1.0.0"
  vpc_id         = module.vpc.vpc_id
  vpc_cidr       = module.vpc.vpc_cidr
  rds_port       = var.rds_engine == "mysql" ? 3306 : 5432
}
${% endif %}

# ────────────────────────────────────────────────────────────────
# EC2
# ${% if values.provision_ec2 %}Provisioned${% else %}Not selected${% endif %}
# ────────────────────────────────────────────────────────────────

${% if values.provision_ec2 %}
module "iam" {
  source = "./modules/iam-baseline"

  client_name        = var.client_name
  environment        = var.environment
  module_version     = "1.0.0"
  ${% if values.provision_s3 %}
  ec2_s3_bucket_arns = [
    module.s3.bucket_arn,
    "${module.s3.bucket_arn}/*"
  ]
  ${% endif %}
}

module "ec2" {
  source = "./modules/ec2"

  client_name        = var.client_name
  environment        = var.environment
  module_version     = "1.0.0"
  aws_region         = var.aws_region
  subnet_id          = module.subnets.private_subnet_ids[0]
  security_group_ids = [module.security_groups.web_security_group_id]
  instance_type      = var.ec2_instance_type
}
${% endif %}

# ────────────────────────────────────────────────────────────────
# S3
# ${% if values.provision_s3 %}Provisioned${% else %}Not selected${% endif %}
# ────────────────────────────────────────────────────────────────

${% if values.provision_s3 %}
module "s3" {
  source = "./modules/s3"

  client_name       = var.client_name
  environment       = var.environment
  module_version    = "1.0.0"
  bucket_suffix     = "storage"
  enable_versioning = ${{ values.s3_versioning }}
}
${% endif %}

# ────────────────────────────────────────────────────────────────
# RDS
# ${% if values.provision_rds %}Provisioned${% else %}Not selected${% endif %}
# ────────────────────────────────────────────────────────────────

${% if values.provision_rds %}
module "rds" {
  source = "./modules/rds"

  client_name        = var.client_name
  environment        = var.environment
  module_version     = "1.0.0"
  subnet_ids         = module.subnets.private_subnet_ids
  security_group_ids = [module.security_groups.database_security_group_id]
  engine             = var.rds_engine
  master_password    = var.db_master_password
}
${% endif %}
SKELEOF

echo "✅ skeleton/terraform/main.tf created"

# ────────────────────────────────────────────────────────────────
# SKELETON — variables.tf
# ────────────────────────────────────────────────────────────────

cat > templates/aws-infrastructure/skeleton/terraform/variables.tf << 'SKELEOF'
# ================================================================
# ${{ values.client_name }} — ${{ values.environment }} — Variables
# Generated by Opt IT Backstage — DO NOT EDIT MANUALLY
# ================================================================

variable "client_name" {
  description = "Client name"
  type        = string
  default     = "${{ values.client_name }}"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "${{ values.environment }}"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "${{ values.aws_region }}"
}

${% if values.provision_vpc %}
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "${{ values.vpc_cidr }}"
}
${% endif %}

${% if values.provision_ec2 %}
variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "${{ values.ec2_instance_type }}"
}
${% endif %}

${% if values.provision_rds %}
variable "rds_engine" {
  description = "RDS database engine"
  type        = string
  default     = "${{ values.rds_engine }}"
}

variable "db_master_password" {
  description = "RDS master password — set via TF_VAR_db_master_password environment variable or GitHub Secret. Never hardcode."
  type        = string
  sensitive   = true
}
${% endif %}
SKELEOF

echo "✅ skeleton/terraform/variables.tf created"

# ────────────────────────────────────────────────────────────────
# SKELETON — outputs.tf
# ────────────────────────────────────────────────────────────────

cat > templates/aws-infrastructure/skeleton/terraform/outputs.tf << 'SKELEOF'
# ================================================================
# ${{ values.client_name }} — ${{ values.environment }} — Outputs
# Generated by Opt IT Backstage — DO NOT EDIT MANUALLY
# ================================================================

${% if values.provision_vpc %}
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}
${% endif %}

${% if values.provision_ec2 %}
output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "EC2 private IP"
  value       = module.ec2.instance_private_ip
}
${% endif %}

${% if values.provision_s3 %}
output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = module.s3.bucket_arn
}
${% endif %}

${% if values.provision_rds %}
output "rds_endpoint" {
  description = "RDS connection endpoint"
  value       = module.rds.db_endpoint
  sensitive   = true
}
${% endif %}
SKELEOF

echo "✅ skeleton/terraform/outputs.tf created"

# ────────────────────────────────────────────────────────────────
# SKELETON — README for client repo
# ────────────────────────────────────────────────────────────────

cat > templates/aws-infrastructure/skeleton/docs/infrastructure.md << 'SKELEOF'
# Infrastructure — ${{ values.client_name }} (${{ values.environment }})

Generated by **Opt IT Backstage** on ${{ "" | now }}.

## What Was Provisioned

| Resource | Status |
|---|---|
| VPC | ${% if values.provision_vpc %}✅ Provisioned${% else %}❌ Not selected${% endif %} |
| EC2 | ${% if values.provision_ec2 %}✅ Provisioned${% else %}❌ Not selected${% endif %} |
| S3  | ${% if values.provision_s3 %}✅ Provisioned${% else %}❌ Not selected${% endif %} |
| RDS | ${% if values.provision_rds %}✅ Provisioned${% else %}❌ Not selected${% endif %} |

## Configuration

| Setting | Value |
|---|---|
| Client | ${{ values.client_name }} |
| Environment | ${{ values.environment }} |
| AWS Region | ${{ values.aws_region }} |
${% if values.provision_vpc %}| VPC CIDR | ${{ values.vpc_cidr }} |${% endif %}
${% if values.provision_ec2 %}| EC2 Instance Type | ${{ values.ec2_instance_type }} |${% endif %}
${% if values.provision_rds %}| RDS Engine | ${{ values.rds_engine }} |${% endif %}

## How To Apply

```bash
cd terraform/

# 1. Initialise
terraform init

# 2. Review the plan
terraform plan

# 3. Apply
terraform apply
```

${% if values.provision_rds %}
## RDS Password

Set the DB password via environment variable before running terraform:

```bash
export TF_VAR_db_master_password="your-secure-password"
terraform apply
```

Or add `TF_VAR_db_master_password` as a GitHub Secret for CI/CD.
${% endif %}

## Managed By

This infrastructure is managed by **Opt IT Technologies** via Backstage.
Do not make manual changes to AWS resources — they will be overwritten on next apply.
SKELEOF

echo "✅ skeleton/docs/infrastructure.md created"

# ────────────────────────────────────────────────────────────────
# TEMPLATE README
# ────────────────────────────────────────────────────────────────

cat > templates/aws-infrastructure/README.md << 'EOF'
# AWS Infrastructure Template

Backstage scaffolder template that provisions production-grade AWS infrastructure for Opt IT clients.

## What It Does

1. Takes client name, environment, AWS region as input
2. Lets the DevOps engineer select AWS resources via AwsResourcePicker
3. Fetches versioned Terraform modules from opt-it-modules
4. Generates a wired-together root main.tf, variables.tf, outputs.tf
5. Opens a PR on the client's GitHub repository

## Resources Supported

- VPC + Subnets + Security Groups (networking foundation)
- EC2 (compute) + IAM baseline
- S3 (storage)
- RDS — MySQL or PostgreSQL (database)

## IaC Tools Supported

- Terraform (modules pinned to git tags)
- CloudFormation

## Module Versions Used

| Module | Version |
|---|---|
| terraform-aws-vpc | v1.0.0 |
| terraform-aws-subnets | v1.0.0 |
| terraform-aws-security-groups | v1.0.0 |
| terraform-aws-ec2 | v1.0.0 |
| terraform-aws-s3 | v1.0.0 |
| terraform-aws-rds | v1.0.0 |
| terraform-aws-iam-baseline | v1.0.0 |

## Files Generated In Client Repo

```
terraform/
├── main.tf           ← all selected modules wired together
├── variables.tf      ← pre-filled with selected values
├── outputs.tf        ← outputs for all selected resources
└── modules/
    ├── vpc/          ← if VPC selected
    ├── subnets/      ← if VPC selected
    ├── security-groups/ ← if EC2 or RDS selected
    ├── ec2/          ← if EC2 selected
    ├── iam-baseline/ ← if EC2 selected
    ├── s3/           ← if S3 selected
    └── rds/          ← if RDS selected
docs/
└── infrastructure.md ← auto-generated infrastructure docs
```

## How To Add A New Module

1. Build the module in opt-it-modules following the module standards
2. Tag it: `git tag terraform-aws-{name}-v1.0.0`
3. Add a fetch step in template.yaml pointing to the new tag
4. Add the module call to skeleton/terraform/main.tf using `${% if values.provision_{name} %}` conditionals
5. Add the variable to skeleton/terraform/variables.tf
6. Update this README with the new module version

## Phase

Phase 1 — AWS Infrastructure only.
Azure and GCP templates will follow in Phase 2.
EOF

echo "✅ README.md created"

# ────────────────────────────────────────────────────────────────
# CATALOG ROOT — registers all templates in Backstage
# ────────────────────────────────────────────────────────────────

cat > catalog-info.yaml << 'EOF'
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: opt-it-catalog
  description: Opt IT Backstage Template Catalog
spec:
  targets:
    - ./templates/aws-infrastructure/template.yaml
EOF

echo "✅ catalog-info.yaml created"

# ────────────────────────────────────────────────────────────────
# COMMIT AND PUSH
# ────────────────────────────────────────────────────────────────

echo ""
echo "================================================================"
echo "  Committing and pushing..."
echo "================================================================"

git add .
git commit -m "feat(aws-infrastructure): add atomic AWS infrastructure template v1.0.0"
git push origin main

echo ""
echo "================================================================"
echo "  ✅ AWS Infrastructure template pushed to opt-it-catalog!"
echo ""
echo "  Next step: Register catalog-info.yaml in your Backstage app.yaml"
echo "  Add this to your app-config.yaml catalog.locations:"
echo ""
echo "    - type: url"
echo "      target: https://github.com/equaan/opt-it-catalog/blob/main/catalog-info.yaml"
echo "================================================================"