# Changelog — terraform-azure-blob-storage

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Storage Account with configurable replication type
- HTTPS-only access enforced — cannot be disabled
- TLS 1.2 minimum enforced — cannot be disabled
- Public blob access blocked — all containers are private by default
- Optional blob versioning
- Optional soft delete for blobs and containers with configurable retention
- Multiple blob containers via container_names list
- Storage account name auto-generated to meet Azure naming constraints (no hyphens, max 24 chars)
- Outputs: storage_account_id, storage_account_name, primary_blob_endpoint, primary_access_key (sensitive), primary_connection_string (sensitive), container_names
