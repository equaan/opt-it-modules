# Changelog — terraform-aws-vpc

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- VPC resource with configurable CIDR block
- Internet Gateway attached to VPC
- Optional NAT Gateway with Elastic IP for private subnet internet access
- Default security group locked down to deny all traffic
- Standard Opt IT tagging on all resources (Client, Environment, ManagedBy, ModuleVersion, ProvisionedBy)
- Input validation for client_name (lowercase alphanumeric + hyphens only)
- Input validation for environment (dev / staging / prod only)
- Input validation for vpc_cidr (must be valid CIDR)
- Outputs: vpc_id, vpc_cidr, internet_gateway_id, nat_gateway_id, nat_gateway_public_ip, name_prefix, standard_tags
