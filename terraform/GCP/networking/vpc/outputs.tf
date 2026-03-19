output "vpc_id" {
  description = "The ID of the VPC network. Pass to firewall, gce, and cloud-sql modules."
  value       = google_compute_network.this.id
}

output "vpc_name" {
  description = "The name of the VPC network."
  value       = google_compute_network.this.name
}

output "vpc_self_link" {
  description = "The self_link of the VPC. Required by some GCP resources."
  value       = google_compute_network.this.self_link
}

output "public_subnet_name" {
  description = "Name of the public subnet."
  value       = google_compute_subnetwork.public.name
}

output "public_subnet_self_link" {
  description = "Self link of the public subnet."
  value       = google_compute_subnetwork.public.self_link
}

output "private_subnet_name" {
  description = "Name of the private subnet."
  value       = google_compute_subnetwork.private.name
}

output "private_subnet_self_link" {
  description = "Self link of the private subnet. Pass to gce module as subnetwork."
  value       = google_compute_subnetwork.private.self_link
}

output "name_prefix" {
  description = "Naming prefix used across all resources."
  value       = local.name_prefix
}

output "standard_labels" {
  description = "Standard labels applied to all resources."
  value       = local.standard_labels
}
