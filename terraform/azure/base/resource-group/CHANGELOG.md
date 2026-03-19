# Changelog — terraform-azure-resource-group

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Resource Group with configurable location and optional name suffix
- Standard Opt IT tagging on all resources
- Input validation for client_name, environment, subscription_id
- Outputs: resource_group_name, resource_group_id, location, name_prefix, standard_tags
- Provider configuration with explicit subscription_id
