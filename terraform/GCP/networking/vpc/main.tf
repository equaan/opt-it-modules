# ─────────────────────────────────────────────────────────────
# PROVIDER
# Uses Application Default Credentials (ADC) automatically.
# Run: gcloud auth application-default login
# ─────────────────────────────────────────────────────────────

provider "google" {
  project = var.project_id
  region  = var.region
}

# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# NOTE: GCP uses labels (key-value pairs) not tags like AWS/Azure
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_labels = merge(
    {
      client        = var.client_name
      environment   = var.environment
      managed_by    = "opt-it-backstage"
      module        = "terraform-gcp-vpc"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

# ─────────────────────────────────────────────────────────────
# VPC NETWORK
# GCP VPCs are global — no region needed here
# custom_subnet_mode = we manage subnets explicitly
# ─────────────────────────────────────────────────────────────

resource "google_compute_network" "this" {
  name                    = "${local.name_prefix}-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false  # we manage subnets explicitly
  description             = "VPC for ${var.client_name} ${var.environment} — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# PUBLIC SUBNET
# Resources here get external IPs
# ─────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "public" {
  name                     = "${local.name_prefix}-public-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.public_subnet_cidr
  private_ip_google_access = true  # allows access to Google APIs without external IP
  description              = "Public subnet for ${var.client_name} ${var.environment}"
}

# ─────────────────────────────────────────────────────────────
# PRIVATE SUBNET
# Resources here have internal IPs only
# ─────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "private" {
  name                     = "${local.name_prefix}-private-subnet"
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.this.id
  ip_cidr_range            = var.private_subnet_cidr
  private_ip_google_access = true  # allows private VMs to reach Google APIs
  description              = "Private subnet for ${var.client_name} ${var.environment}"
}

# ─────────────────────────────────────────────────────────────
# CLOUD NAT — optional
# Allows private subnet VMs to reach the internet
# Without this, private VMs are fully isolated
# ─────────────────────────────────────────────────────────────

resource "google_compute_router" "this" {
  count   = var.enable_cloud_nat ? 1 : 0
  name    = "${local.name_prefix}-router"
  project = var.project_id
  region  = var.region
  network = google_compute_network.this.id
}

resource "google_compute_router_nat" "this" {
  count                              = var.enable_cloud_nat ? 1 : 0
  name                               = "${local.name_prefix}-nat"
  project                            = var.project_id
  router                             = google_compute_router.this[0].name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.private.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}
