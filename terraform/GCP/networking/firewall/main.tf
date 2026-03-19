# ─────────────────────────────────────────────────────────────
# PROVIDER
# ─────────────────────────────────────────────────────────────

provider "google" {
  project = var.project_id
}

# ─────────────────────────────────────────────────────────────
# LOCAL VALUES
# ─────────────────────────────────────────────────────────────

locals {
  name_prefix = "${var.client_name}-${var.environment}"

  standard_labels = merge(
    {
      client         = var.client_name
      environment    = var.environment
      managed_by     = "opt-it-backstage"
      module         = "terraform-gcp-firewall"
      provisioned_by = "terraform"
    },
    var.additional_labels
  )
}

# ─────────────────────────────────────────────────────────────
# HTTP INBOUND — targets VMs tagged "web-server"
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_http" {
  count   = length(var.allowed_http_source_ranges) > 0 ? 1 : 0
  name    = "${local.name_prefix}-allow-http"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = var.allowed_http_source_ranges
  target_tags   = ["web-server"]  # only VMs with this tag receive this rule
  description   = "Allow HTTP inbound to web-server tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# HTTPS INBOUND — targets VMs tagged "web-server"
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_https" {
  count   = length(var.allowed_https_source_ranges) > 0 ? 1 : 0
  name    = "${local.name_prefix}-allow-https"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = var.allowed_https_source_ranges
  target_tags   = ["web-server"]
  description   = "Allow HTTPS inbound to web-server tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# SSH INBOUND — targets VMs tagged "ssh-access"
# Only created if allowed_ssh_source_ranges is provided
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_ssh" {
  count   = length(var.allowed_ssh_source_ranges) > 0 ? 1 : 0
  name    = "${local.name_prefix}-allow-ssh"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_source_ranges
  target_tags   = ["ssh-access"]
  description   = "Allow SSH inbound from approved IPs to ssh-access tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# DB PORT — internal VPC traffic only
# Targets VMs tagged "db-server"
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_db_internal" {
  name    = "${local.name_prefix}-allow-db-internal"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
    ports    = [tostring(var.db_port)]
  }

  # Only allow from within VPC — no internet access to DB
  source_ranges = ["10.0.0.0/8"]
  target_tags   = ["db-server"]
  description   = "Allow DB port inbound from VPC CIDR only to db-server tagged VMs — managed by Opt IT Backstage"
}

# ─────────────────────────────────────────────────────────────
# INTERNAL VPC TRAFFIC
# Allows all traffic between resources within the VPC
# ─────────────────────────────────────────────────────────────

resource "google_compute_firewall" "allow_internal" {
  name    = "${local.name_prefix}-allow-internal"
  project = var.project_id
  network = var.vpc_name

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
  description   = "Allow all internal VPC traffic — managed by Opt IT Backstage"
}
