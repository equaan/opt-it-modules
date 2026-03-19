# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"
  bucket_name = "${var.client_name}-${var.environment}-${var.bucket_suffix}"

  standard_tags = merge(
    {
      Client        = var.client_name
      Environment   = var.environment
      ManagedBy     = "opt-it-backstage"
      ModuleVersion = var.module_version
      ProvisionedBy = "terraform"
      Module        = "terraform-aws-s3"
    },
    var.additional_tags
  )
}

# ─────────────────────────────────────────────────────────────
# S3 BUCKET
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(local.standard_tags, {
    Name = local.bucket_name
  })
}

# ─────────────────────────────────────────────────────────────
# BLOCK ALL PUBLIC ACCESS — enforced on every bucket
# Override only via explicit bucket policy if needed
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ─────────────────────────────────────────────────────────────
# SERVER SIDE ENCRYPTION — enforced on every bucket
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# ─────────────────────────────────────────────────────────────
# VERSIONING — optional, recommended for prod
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ─────────────────────────────────────────────────────────────
# LIFECYCLE RULES — optional, manages old versions automatically
# ─────────────────────────────────────────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.enable_lifecycle_rules ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "noncurrent-version-management"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
