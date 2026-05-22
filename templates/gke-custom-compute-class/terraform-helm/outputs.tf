output "cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}

output "cluster_endpoint" {
  value       = google_container_cluster.primary.endpoint
  description = "GKE Cluster Endpoint"
}

output "network_name" {
  value       = google_compute_network.vpc.name
  description = "VPC Network Name"
}

output "subnet_name" {
  value       = google_compute_subnetwork.subnet.name
  description = "Subnet Name"
}
