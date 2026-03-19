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
      Module        = "terraform-aws-iam-baseline"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# EC2 INSTANCE ROLE
# Allows EC2 instances to call AWS APIs using instance metadata
# Attach to EC2 via instance profile
# ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2" {
  count = var.create_ec2_role ? 1 : 0

  name        = "${local.name_prefix}-ec2-role"
  description = "IAM role for EC2 instances in ${var.client_name} ${var.environment}. Managed by Opt IT Backstage."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(local.standard_tags, {
    Name = "${local.name_prefix}-ec2-role"
  })
}

# SSM Session Manager — allows shell access without SSH keys or bastion hosts
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  count      = var.create_ec2_role ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent — allows EC2 to push logs and metrics
resource "aws_iam_role_policy_attachment" "ec2_cloudwatch" {
  count      = var.create_ec2_role ? 1 : 0
  role       = aws_iam_role.ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# S3 access — only created if bucket ARNs are provided
resource "aws_iam_role_policy" "ec2_s3" {
  count = var.create_ec2_role && length(var.ec2_s3_bucket_arns) > 0 ? 1 : 0

  name = "${local.name_prefix}-ec2-s3-policy"
  role = aws_iam_role.ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = var.ec2_s3_bucket_arns
      }
    ]
  })
}

# Instance profile — wraps the role so it can be attached to EC2
resource "aws_iam_instance_profile" "ec2" {
  count = var.create_ec2_role ? 1 : 0

  name = "${local.name_prefix}-ec2-instance-profile"
  role = aws_iam_role.ec2[0].name

  tags = local.standard_tags
}
