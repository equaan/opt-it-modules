# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-ec2"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# AMI — Latest Amazon Linux 2023
# Only used when ami_id is not explicitly provided
# ─────────────────────────────────────────────────────────────

data "aws_ami" "amazon_linux_2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  resolved_ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id
}

# ─────────────────────────────────────────────────────────────
# EC2 INSTANCE
# ─────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami                    = local.resolved_ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name               = var.key_name != "" ? var.key_name : null
  monitoring             = var.enable_detailed_monitoring
  user_data_base64       = var.user_data != "" ? base64encode(var.user_data) : null

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    encrypted             = true  # always encrypt at rest
    delete_on_termination = true

    tags = merge(local.standard_tags, {
      Name = "${local.name_prefix}-ec2-root-volume"
    })
  }

  # Prevent accidental termination in production
  disable_api_termination = var.environment == "prod" ? true : false

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-ec2"
  })

  lifecycle {
    # AMI ID changes frequently — ignore to prevent unwanted replacement
    ignore_changes = [ami]
  }
}
