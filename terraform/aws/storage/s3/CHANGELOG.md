# Changelog — terraform-aws-s3

All notable changes to this module will be documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This module follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-03-18

### Added
- S3 bucket with configurable name suffix
- Public access block enforced on all buckets — cannot be disabled
- Server-side encryption (AES256) enforced on all buckets — cannot be disabled
- Optional versioning
- Optional lifecycle rules for noncurrent version management
- force_destroy toggle — defaults to false for safety
- Standard Opt IT tagging
