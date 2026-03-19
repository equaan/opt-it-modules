variable "client_name" {
  description = "Client name. Lowercase alphanumeric and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.client_name))
    error_message = "client_name must be lowercase alphanumeric and hyphens only."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "module_version" {
  description = "Version of this module. Injected by Backstage."
  type        = string
  default     = "1.0.0"
}

variable "project_id" {
  description = "GCP Project ID."
  type        = string
}

variable "region" {
  description = "GCP region. Must match the region used in the vpc module."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone within the region. Example: us-central1-a, us-central1-b"
  type        = string
  default     = "us-central1-a"
}

variable "subnetwork_self_link" {
  description = "Self link of the subnet to place the VM in. Use private subnet. Passed from module.vpc.private_subnet_self_link"
  type        = string
}

variable "machine_type" {
  description = "GCE machine type. dev: e2-medium, prod: n2-standard-2. See https://cloud.google.com/compute/docs/machine-resource"
  type        = string
  default     = "e2-medium"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. Minimum 10 GB."
  type        = number
  default     = 20

  validation {
    condition     = var.boot_disk_size_gb >= 10
    error_message = "boot_disk_size_gb must be at least 10 GB."
  }
}

variable "boot_disk_type" {
  description = "Boot disk type. pd-standard: HDD (dev), pd-ssd: SSD (prod), pd-balanced: balanced SSD."
  type        = string
  default     = "pd-standard"

  validation {
    condition     = contains(["pd-standard", "pd-ssd", "pd-balanced"], var.boot_disk_type)
    error_message = "boot_disk_type must be pd-standard, pd-ssd, or pd-balanced."
  }
}

variable "image" {
  description = "Boot disk image. Default: latest Debian 12. Example: debian-cloud/debian-12, ubuntu-os-cloud/ubuntu-2204-lts"
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "network_tags" {
  description = "Network tags to apply to the VM. Tags control which firewall rules apply. Example: [\"web-server\", \"ssh-access\"]. Use the output tags from the firewall module."
  type        = list(string)
  default     = []
}

variable "enable_public_ip" {
  description = "Whether to assign a public IP. Set to false for private VMs — use Cloud IAP or Cloud NAT for access."
  type        = bool
  default     = false
}

variable "metadata_startup_script" {
  description = "Startup script to run on first boot. Leave empty for no startup script."
  type        = string
  default     = ""
}

variable "service_account_email" {
  description = "Service account email to attach to the VM. Leave empty to use the Compute Engine default service account."
  type        = string
  default     = ""
}

variable "additional_labels" {
  description = "Additional GCP labels. Merged with standard Opt IT labels."
  type        = map(string)
  default     = {}
}
