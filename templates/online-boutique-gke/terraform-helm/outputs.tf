output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "The cluster endpoint"
  value       = google_container_cluster.primary.endpoint
}

output "cluster_location" {
  description = "The cluster location (region)"
  value       = google_container_cluster.primary.location
}
