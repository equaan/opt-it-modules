# Changelog — terraform-azure-sql-flexible

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- PostgreSQL Flexible Server with configurable version, SKU, and storage
- MySQL Flexible Server with configurable version, SKU, and storage
- Single module handles both engines via db_engine variable
- Private networking via delegated subnet and private DNS zone
- Optional high availability — Disabled, SameZone, or ZoneRedundant
- Optional geo-redundant backups
- Configurable backup retention (1-35 days)
- Maintenance window set to 3am Sunday UTC
- Initial database created automatically on server
- Reserved admin username validation
- Standard Opt IT tagging on all resources
- Outputs: server_id, server_name, server_fqdn, database_name, admin_username, db_engine, db_port
