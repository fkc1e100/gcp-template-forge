output "cluster_name" {
  value = google_container_cluster.hello_world_cluster.name
}

output "cluster_location" {
  value = google_container_cluster.hello_world_cluster.location
}

output "cluster_endpoint" {
  value = google_container_cluster.hello_world_cluster.endpoint
}

output "hello_world_service_ip" {
  value = try(kubernetes_service.hello_world.status[0].load_balancer[0].ingress[0].ip, "Provisioning...")
}
