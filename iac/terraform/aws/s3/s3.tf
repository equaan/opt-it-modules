resource "aws_s3_bucket" "client_storage" {
  bucket        = "${{ values.client_name }}-app-storage-bucket"
  force_destroy = true
}

# Standard company security policy for all new buckets
resource "aws_s3_bucket_public_access_block" "client_storage_block" {
  bucket = aws_s3_bucket.client_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
