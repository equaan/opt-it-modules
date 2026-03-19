provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_labels = merge(
    {
      client         = var.client_name
      environment    = var.environment
      managed_by     = "opt-it-backstage"
      module         = "terraform-gcp-gce"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

resource "google_compute_instance" "this" {
  name         = "${local.name_prefix}-vm"
  project      = var.project_id
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.network_tags  # these control which firewall rules apply
  labels       = local.standard_labels

  boot_disk {
    initialize_params {
      image = var.image
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
      labels = local.standard_labels
    }
  }

  network_interface {
    subnetwork = var.subnetwork_self_link

    # Public IP — only assigned when enable_public_ip = true
    dynamic "access_config" {
      for_each = var.enable_public_ip ? [1] : []
      content {
        # Empty access_config = ephemeral public IP
      }
    }
  }

  # Service account
  dynamic "service_account" {
    for_each = var.service_account_email != "" ? [1] : []
    content {
      email  = var.service_account_email
      scopes = ["cloud-platform"]
    }
  }

  # Startup script
  metadata = var.metadata_startup_script != "" ? {
    startup-script = var.metadata_startup_script
  } : {}

  # Enable OS Login — SSH key management via GCP IAM
  # This is the recommended approach instead of managing SSH keys manually
  metadata_startup_script = null

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    ignore_changes = [metadata_startup_script]
  }
}
