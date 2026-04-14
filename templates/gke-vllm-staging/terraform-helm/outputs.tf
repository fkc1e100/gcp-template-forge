output "cluster_name" {
  value = google_container_cluster.main.name
}

output "cluster_location" {
  value = google_container_cluster.main.location
}

output "bucket_name" {
  value = google_storage_bucket.weights.name
}
