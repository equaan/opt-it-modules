# terraform-aws-vpc

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/equaan/opt-it-modules/releases/tag/terraform-aws-vpc-v1.0.0)

Provisions a production-grade AWS VPC for an Opt IT client environment.

Includes an Internet Gateway, optional NAT Gateway, and a locked-down default security group. All resources follow Opt IT standard tagging conventions.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_vpc` | The VPC with configurable CIDR |
| `aws_internet_gateway` | Attached to VPC for public internet access |
| `aws_eip` | Elastic IP for NAT Gateway (if enabled) |
| `aws_nat_gateway` | NAT Gateway for private subnet egress (if enabled) |
| `aws_default_security_group` | Locked down — denies all traffic by default |

---

## Usage

```hcl
module "vpc" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/networking/vpc?ref=terraform-aws-vpc-v1.0.0"

  client_name  = "acme-corp"
  environment  = "prod"
  aws_region   = "us-east-1"

  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = true
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name — lowercase alphanumeric and hyphens | `string` | — | ✅ |
| `environment` | Deployment environment: dev / staging / prod | `string` | — | ✅ |
| `module_version` | Module version — injected by Backstage | `string` | `"1.0.0"` | ❌ |
| `aws_region` | AWS region | `string` | `"us-east-1"` | ❌ |
| `vpc_cidr` | CIDR block for the VPC | `string` | `"10.0.0.0/16"` | ❌ |
| `enable_dns_hostnames` | Enable DNS hostnames in VPC | `bool` | `true` | ❌ |
| `enable_dns_support` | Enable DNS support in VPC | `bool` | `true` | ❌ |
| `enable_nat_gateway` | Provision a NAT Gateway | `bool` | `false` | ❌ |
| `additional_tags` | Extra tags merged with standard tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | VPC ID — consumed by subnets, ec2, rds, eks modules |
| `vpc_cidr` | VPC CIDR block |
| `internet_gateway_id` | Internet Gateway ID |
| `nat_gateway_id` | NAT Gateway ID (empty if disabled) |
| `nat_gateway_public_ip` | NAT Gateway public IP (empty if disabled) |
| `default_security_group_id` | Locked-down default SG — do not use directly |
| `name_prefix` | Naming prefix used across all resources |
| `standard_tags` | Standard tags applied to all resources |

---

## Resource Naming Convention

All resources follow this pattern:
```
{client_name}-{environment}-{resource}

Examples:
  acme-corp-prod-vpc
  acme-corp-prod-igw
  acme-corp-prod-nat
  acme-corp-prod-nat-eip
```

---

## Standard Tags Applied

Every resource gets these tags:

| Tag | Value |
|---|---|
| `Client` | Value of `var.client_name` |
| `Environment` | Value of `var.environment` |
| `ManagedBy` | `opt-it-backstage` |
| `ModuleVersion` | Value of `var.module_version` |
| `ProvisionedBy` | `terraform` |
| `Module` | `terraform-aws-vpc` |

---

## Notes

- NAT Gateway has an hourly AWS cost. Only enable for environments that require private subnet internet egress (typically staging and prod).
- The default security group is intentionally locked down. Use the `security-groups` module to create explicit security groups.
- DNS hostnames and DNS support are enabled by default — required for EKS, RDS, and service discovery.

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-vpc-v1.0.0`
