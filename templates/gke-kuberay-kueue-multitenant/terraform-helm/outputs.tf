output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_location" {
  description = "The location (region/zone) of the GKE cluster"
  value       = google_container_cluster.primary.location
}
