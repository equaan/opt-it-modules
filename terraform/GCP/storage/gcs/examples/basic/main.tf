module "gcs" {
  source        = "../../"
  client_name   = "example-client"
  environment   = "dev"
  project_id    = "example-project-123456"
  bucket_suffix = "uploads"
}

output "bucket_url" { value = module.gcs.bucket_url }
