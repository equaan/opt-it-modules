output "instance_id" {
  description = "The GCE instance ID."
  value       = google_compute_instance.this.instance_id
}

output "instance_name" {
  description = "The name of the GCE instance."
  value       = google_compute_instance.this.name
}

output "internal_ip" {
  description = "Internal IP address of the instance."
  value       = google_compute_instance.this.network_interface[0].network_ip
}

output "external_ip" {
  description = "External IP address of the instance. Empty if enable_public_ip = false."
  value       = var.enable_public_ip ? google_compute_instance.this.network_interface[0].access_config[0].nat_ip : ""
}

output "self_link" {
  description = "Self link of the GCE instance."
  value       = google_compute_instance.this.self_link
}
