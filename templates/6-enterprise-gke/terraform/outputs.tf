output "cluster_endpoint" {
  description = "The IP address of this cluster's master endpoint"
  value       = google_container_cluster.enterprise_cluster.endpoint
}

output "cluster_ca_certificate" {
  description = "The public certificate that is the root of trust for the cluster"
  value       = google_container_cluster.enterprise_cluster.master_auth[0].cluster_ca_certificate
}

output "cluster_name" {
  description = "The name of the cluster"
  value       = google_container_cluster.enterprise_cluster.name
}
