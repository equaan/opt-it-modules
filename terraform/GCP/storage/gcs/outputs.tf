output "bucket_name" {
  description = "The name of the GCS bucket."
  value       = google_storage_bucket.this.name
}

output "bucket_url" {
  description = "The URL of the GCS bucket. Format: gs://bucket-name"
  value       = "gs://${google_storage_bucket.this.name}"
}

output "bucket_self_link" {
  description = "The self_link of the bucket."
  value       = google_storage_bucket.this.self_link
}
