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
