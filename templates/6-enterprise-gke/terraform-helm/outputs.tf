output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.enterprise_cluster.name
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = google_container_cluster.enterprise_cluster.location
}

output "vpc_name" {
  description = "The name of the VPC"
  value       = google_compute_network.vpc.name
}
