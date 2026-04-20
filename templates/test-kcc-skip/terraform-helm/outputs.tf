output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = var.cluster_name
}

output "cluster_location" {
  description = "The location of the GKE cluster"
  value       = var.region
}
