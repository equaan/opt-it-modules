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
      module         = "terraform-gcp-cloud-sql"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

# Private service access — required for Cloud SQL private IP
resource "google_compute_global_address" "private_ip_range" {
  name          = "${local.name_prefix}-sql-private-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = var.vpc_self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = var.vpc_self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]
}

resource "google_sql_database_instance" "this" {
  name             = "${local.name_prefix}-sql"
  project          = var.project_id
  region           = var.region
  database_version = var.db_version

  deletion_protection = var.environment == "prod" ? true : false

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = var.disk_size_gb
    disk_autoresize   = true
    user_labels       = local.standard_labels

    ip_configuration {
      ipv4_enabled                                  = false  # private IP only
      private_network                               = var.vpc_self_link
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = var.backup_enabled
      start_time = "03:00"
    }
  }

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "this" {
  name     = "appdb"
  project  = var.project_id
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "root" {
  name     = var.db_engine == "postgres" ? "postgres" : "root"
  project  = var.project_id
  instance = google_sql_database_instance.this.name
  password = var.admin_password
}
