# Changelog — terraform-gcp-gce

All notable changes to this module will be documented here.

---

## [1.0.0] - 2026-03-19

### Added
- GCE instance with configurable machine type, boot disk, and image
- Network tags support for firewall rule targeting
- Shielded VM config enabled (Secure Boot, vTPM, Integrity Monitoring)
- Optional public IP via ephemeral access_config
- Optional service account attachment
- Optional startup script via metadata
- Standard Opt IT labeling
- Outputs: instance_id, instance_name, internal_ip, external_ip, self_link
