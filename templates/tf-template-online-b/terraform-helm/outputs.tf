output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "kubernetes_endpoint" {
  description = "The GKE control plane endpoint"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "subnet_name" {
  description = "The name of the subnetwork"
  value       = google_compute_subnetwork.subnet.name
}
