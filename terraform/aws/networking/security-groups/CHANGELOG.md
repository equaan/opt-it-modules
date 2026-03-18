# Changelog — terraform-aws-security-groups

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- Web/app tier security group — HTTP (80), HTTPS (443), optional SSH inbound
- Database tier security group — DB port inbound from web SG only, no internet access
- Internal services security group — VPC-internal traffic only
- SSH access blocked from 0.0.0.0/0 by validation rule — must provide specific CIDRs
- Standard Opt IT tagging on all resources
- Tier tag (web / database / internal) on each security group
- create_before_destroy lifecycle on all security groups
