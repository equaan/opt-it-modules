# terraform-aws-ec2

Provisions a single EC2 instance with encrypted EBS volume, configurable instance type, and production safeguards.

Depends on `terraform-aws-subnets` and `terraform-aws-security-groups`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `aws_instance` | EC2 instance with encrypted root volume |
| `data.aws_ami` | Auto-resolves latest Amazon Linux 2023 (if ami_id not set) |

---

## Usage

```hcl
module "ec2" {
  source = "github.com/equaan/opt-it-modules//terraform/aws/compute/ec2?ref=terraform-aws-ec2-v1.0.0"

  client_name = "acme-corp"
  environment = "prod"
  aws_region  = "us-east-1"

  subnet_id          = module.subnets.private_subnet_ids[0]
  security_group_ids = [module.security_groups.web_security_group_id]

  instance_type    = "t3.medium"
  root_volume_size = 30
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `subnet_id` | Subnet ID from subnets module | `string` | — | ✅ |
| `security_group_ids` | Security group IDs | `list(string)` | — | ✅ |
| `instance_type` | EC2 instance type | `string` | `t3.micro` | ❌ |
| `ami_id` | AMI ID — empty = latest Amazon Linux 2023 | `string` | `""` | ❌ |
| `key_name` | EC2 key pair name for SSH | `string` | `""` | ❌ |
| `root_volume_size` | Root volume size in GB | `number` | `20` | ❌ |
| `root_volume_type` | Root volume type | `string` | `gp3` | ❌ |
| `enable_detailed_monitoring` | CloudWatch detailed monitoring | `bool` | `false` | ❌ |
| `user_data` | User data script | `string` | `""` | ❌ |
| `additional_tags` | Extra tags | `map(string)` | `{}` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `instance_id` | EC2 instance ID |
| `instance_private_ip` | Private IP |
| `instance_public_ip` | Public IP (empty if private subnet) |
| `instance_arn` | Instance ARN |
| `instance_type` | Instance type used |
| `ami_id` | AMI ID used |

---

## Notes

- Root EBS volume is always encrypted — cannot be disabled
- API termination protection is automatically enabled for `prod` environments
- AMI ID is ignored in lifecycle to prevent unwanted instance replacement on AMI updates

---

## Version History

See [CHANGELOG.md](./CHANGELOG.md)

---

## Module Version

`terraform-aws-ec2-v1.0.0`
