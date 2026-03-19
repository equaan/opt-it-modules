# Changelog — terraform-azure-vnet

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Virtual Network with configurable address space
- Public subnets — configurable count via public_subnet_prefixes list
- Private subnets — configurable count via private_subnet_prefixes list
- Optional NAT Gateway with Public IP for private subnet internet egress
- NAT Gateway associated with all private subnets automatically
- Standard Opt IT tagging on all resources
- Outputs: vnet_id, vnet_name, public_subnet_ids, private_subnet_ids, nat_gateway_id
