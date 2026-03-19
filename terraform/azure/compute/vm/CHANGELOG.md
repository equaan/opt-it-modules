# Changelog — terraform-azure-vm

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Azure Linux VM (Ubuntu 22.04 LTS default) with configurable size and OS disk
- Network Interface Card (NIC) connected to specified subnet
- Optional static public IP
- SSH key authentication support — password auth disabled when SSH key provided
- OS disk encryption via platform-managed keys (always enabled)
- Boot diagnostics enabled automatically
- delete_os_disk_on_deletion = false for prod environments
- Cloud-init custom data support
- image version ignored in lifecycle to prevent unwanted VM replacement
- Standard Opt IT tagging on all resources
- Outputs: vm_id, vm_name, private_ip_address, public_ip_address, nic_id, admin_username
