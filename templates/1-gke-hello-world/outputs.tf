output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "service_ip" {
  description = "The IP address of the hello world service"
  value       = kubernetes_service.hello_world.status[0].load_balancer[0].ingress[0].ip
}
