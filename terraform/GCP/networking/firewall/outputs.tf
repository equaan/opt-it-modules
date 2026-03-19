output "web_server_tag" {
  description = "Network tag to apply to web-server GCE instances to receive HTTP/HTTPS firewall rules."
  value       = "web-server"
}

output "ssh_access_tag" {
  description = "Network tag to apply to GCE instances that need SSH access."
  value       = "ssh-access"
}

output "db_server_tag" {
  description = "Network tag to apply to database GCE instances."
  value       = "db-server"
}
