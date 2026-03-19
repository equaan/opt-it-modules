# Changelog — terraform-aws-rds

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- RDS instance supporting MySQL and PostgreSQL engines
- RDS subnet group requiring minimum 2 subnets across AZs
- Storage encryption enforced — cannot be disabled
- Publicly accessible set to false — cannot be disabled
- Deletion protection and final snapshot automatically enforced for prod environments
- Performance Insights automatically enabled for prod environments
- Storage autoscaling via max_allocated_storage
- Multi-AZ toggle
- Configurable backup retention (default: 7 days)
- Standard Opt IT tagging
