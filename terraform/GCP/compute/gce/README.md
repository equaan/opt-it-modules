# terraform-gcp-gce

Provisions a GCE (Google Compute Engine) instance with Shielded VM, network tags, and optional public IP.

Depends on `terraform-gcp-vpc` and `terraform-gcp-firewall`.

---

## What This Module Creates

| Resource | Description |
|---|---|
| `google_compute_instance` | GCE VM with Shielded VM config enabled |

---

## Network Tags

Apply firewall tags from the firewall module:

```hcl
module "gce" {
  # ...
  network_tags = [
    module.firewall.web_server_tag,   # "web-server"
    module.firewall.ssh_access_tag,   # "ssh-access"
  ]
}
```

---

## Usage

```hcl
module "gce" {
  source = "github.com/equaan/opt-it-modules//terraform/gcp/compute/gce?ref=terraform-gcp-gce-v1.0.0"

  client_name          = "acme-corp"
  environment          = "prod"
  project_id           = "acme-corp-prod-123456"
  region               = "us-central1"
  zone                 = "us-central1-a"
  subnetwork_self_link = module.vpc.private_subnet_self_link
  machine_type         = "n2-standard-2"
  boot_disk_type       = "pd-ssd"
  network_tags         = [module.firewall.web_server_tag]
}
```

---

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `client_name` | Client name | `string` | — | ✅ |
| `environment` | dev / staging / prod | `string` | — | ✅ |
| `project_id` | GCP Project ID | `string` | — | ✅ |
| `region` | GCP region | `string` | `us-central1` | ❌ |
| `zone` | GCP zone | `string` | `us-central1-a` | ❌ |
| `subnetwork_self_link` | Subnet self_link from vpc module | `string` | — | ✅ |
| `machine_type` | GCE machine type | `string` | `e2-medium` | ❌ |
| `boot_disk_size_gb` | Boot disk size in GB | `number` | `20` | ❌ |
| `boot_disk_type` | Boot disk type | `string` | `pd-standard` | ❌ |
| `image` | Boot disk image | `string` | `debian-cloud/debian-12` | ❌ |
| `network_tags` | Firewall targeting tags | `list(string)` | `[]` | ❌ |
| `enable_public_ip` | Assign public IP | `bool` | `false` | ❌ |
| `metadata_startup_script` | Startup script | `string` | `""` | ❌ |
| `service_account_email` | Service account to attach | `string` | `""` | ❌ |

---

## Outputs

| Name | Description |
|---|---|
| `instance_id` | Instance ID |
| `instance_name` | Instance name |
| `internal_ip` | Internal IP |
| `external_ip` | External IP (empty if disabled) |
| `self_link` | Instance self_link |

---

## Module Version

`terraform-gcp-gce-v1.0.0`
