# Changelog — terraform-aws-iam-baseline

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- EC2 IAM role with assume role policy for ec2.amazonaws.com
- SSM Session Manager policy attached — enables shell access without SSH or bastion hosts
- CloudWatch Agent policy attached — enables log and metric publishing
- Optional S3 read/write policy for specified bucket ARNs
- EC2 instance profile wrapping the role
- Standard Opt IT tagging
