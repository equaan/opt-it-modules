# Changelog — terraform-azure-nsg

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Public NSG — HTTP (80), HTTPS (443), optional SSH inbound, deny all other inbound
- Private NSG — DB port inbound from VNet only, deny all other inbound
- SSH blocked from * and 0.0.0.0/0 by validation rule
- NSGs automatically associated with all public and private subnets
- Tier tag (public / private) on each NSG
- Standard Opt IT tagging on all resources
- Outputs: public_nsg_id, public_nsg_name, private_nsg_id, private_nsg_name
