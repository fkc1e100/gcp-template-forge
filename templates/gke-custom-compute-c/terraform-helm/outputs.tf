output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "The name of the GKE cluster."
}

output "kubernetes_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "The endpoint for the GKE cluster."
  sensitive   = true
}

output "network_name" {
  value       = google_compute_network.vpc.name
  description = "The VPC network name."
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "The subnet name."
}
