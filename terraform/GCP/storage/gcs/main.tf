provider "google" {
  project = var.project_id
}

locals {
  name_prefix = "${var.client_name}-${var.environment}"
  bucket_name = "${var.client_name}-${var.environment}-${var.bucket_suffix}"

  standard_labels = merge(
    {
      client         = var.client_name
      environment    = var.environment
      managed_by     = "opt-it-backstage"
      module         = "terraform-gcp-gcs"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

resource "google_storage_bucket" "this" {
  name          = local.bucket_name
  project       = var.project_id
  location      = var.location
  storage_class = var.storage_class
  force_destroy = var.force_destroy
  labels        = local.standard_labels

  # Block public access — all buckets are private by default
  public_access_prevention = "enforced"

  # Uniform bucket-level access — simpler and more secure than ACLs
  uniform_bucket_level_access = true

  dynamic "versioning" {
    for_each = var.enable_versioning ? [1] : []
    content {
      enabled = true
    }
  }

  dynamic "soft_delete_policy" {
    for_each = var.soft_delete_retention_days > 0 ? [1] : []
    content {
      retention_duration_seconds = var.soft_delete_retention_days * 86400
    }
  }
}
