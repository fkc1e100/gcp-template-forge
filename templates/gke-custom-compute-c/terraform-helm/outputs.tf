output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The name of the GKE cluster."
}

output "network_name" {
  value       = google_compute_network.vpc.name
  description = "The name of the VPC network."
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "The name of the subnetwork."
}

output "endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "The GKE cluster endpoint."
  sensitive   = true
}

output "cluster_location" {
  value       = google_container_cluster.primary.location
  description = "The GKE cluster location (zone or region)."
}

