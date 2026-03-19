# Changelog — terraform-gcp-firewall

All notable changes to this module will be documented here.

---

## [1.0.0] - 2026-03-19

### Added
- HTTP and HTTPS inbound rules targeting web-server tagged VMs
- SSH inbound rule targeting ssh-access tagged VMs (empty = disabled)
- SSH from 0.0.0.0/0 blocked by validation rule
- DB port inbound from VPC CIDR only targeting db-server tagged VMs
- Internal VPC traffic rule (TCP, UDP, ICMP)
- Outputs expose network tag names for use in GCE module
- Standard Opt IT labeling
