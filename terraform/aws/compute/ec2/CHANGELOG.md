# Changelog — terraform-aws-ec2

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- EC2 instance with configurable instance type, subnet, and security groups
- Auto-resolves latest Amazon Linux 2023 AMI when ami_id not provided
- Root EBS volume with encryption enforced, configurable size and type (default: gp3)
- API termination protection enabled automatically for prod environments
- Detailed CloudWatch monitoring toggle
- User data support
- Standard Opt IT tagging on all resources
- AMI ID ignored in lifecycle to prevent unwanted instance replacement
