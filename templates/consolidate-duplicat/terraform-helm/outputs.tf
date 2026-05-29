output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}

output "kubernetes_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Endpoint"
  sensitive   = true
}

output "network_name" {
  value       = google_compute_network.vpc.name
  description = "VPC Network Name"
}
