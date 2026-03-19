module "s3" {
  source        = "../../"
  client_name   = "example-client"
  environment   = "dev"
  bucket_suffix = "uploads"
}

output "bucket_id"  { value = module.s3.bucket_id }
output "bucket_arn" { value = module.s3.bucket_arn }
