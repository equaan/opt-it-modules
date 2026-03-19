# terraform-aws-iam-baseline

Provisions baseline IAM roles and instance profiles for a client environment.

No VPC dependency — IAM is a global AWS service.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_iam_role` (ec2) | Role for EC2 instances to call AWS APIs |
| `aws_iam_role_policy_attachment` (ssm) | Allows SSM Session Manager shell access |
| `aws_iam_role_policy_attachment` (cloudwatch) | Allows CloudWatch log/metric publishing |
| `aws_iam_role_policy` (s3) | S3 read/write access — only if bucket ARNs provided |
| `aws_iam_instance_profile` | Wraps EC2 role for attachment to instances |

---

## Usage

```hcl
module "iam" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/iam/baseline?ref=terraform-aws-iam-baseline-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"

  create_ec2_role    = true
  ec2_s3_bucket_arns = [
    module.s3.bucket_arn,
    "${module.s3.bucket_arn}/*"
  ]
}

# Then pass the instance profile to the ec2 module:
# iam_instance_profile = module.iam.ec2_instance_profile_name
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `create_ec2_role` | Create EC2 role and instance profile | `bool` | `true` | ❌ |
| `ec2_s3_bucket_arns` | S3 bucket ARNs for EC2 access | `list(string)` | `[]` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `ec2_role_arn` | EC2 IAM role ARN |
| `ec2_role_name` | EC2 IAM role name |
| `ec2_instance_profile_name` | Instance profile name — pass to ec2 module |
| `ec2_instance_profile_arn` | Instance profile ARN |

---

## Notes

- SSM Session Manager is always attached — eliminates the need for SSH keys or bastion hosts
- CloudWatch Agent is always attached — required for log and metric collection
- Never grant `*` permissions — use `ec2_s3_bucket_arns` to explicitly specify which buckets

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-iam-baseline-v1.0.0`
