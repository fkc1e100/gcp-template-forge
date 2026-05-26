output "project_id" {
  value = var.project_id
}

output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "network_name" {
  value = google_compute_network.vpc.name
}
