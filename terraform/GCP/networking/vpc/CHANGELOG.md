# Changelog — terraform-gcp-vpc

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-19

### Added
- Global GCP VPC with custom subnet mode
- Public subnet with private_ip_google_access enabled
- Private subnet with private_ip_google_access enabled
- Optional Cloud NAT with Cloud Router for private subnet internet egress
- Application Default Credentials (ADC) authentication
- Standard Opt IT labeling on all resources (GCP uses labels not tags)
- Input validation for client_name, environment, project_id, subnet CIDRs
- Outputs: vpc_id, vpc_name, vpc_self_link, public/private subnet names and self_links
