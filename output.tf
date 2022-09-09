output "port" {
  value       = local.port
  description = "Port number to connect to"
}

output "host" {
  value       = local.host
  description = "Host to connect to"
}

output "kubernetes_host" {
  value       = "https://${local.host}:${local.port}"
  description = "Host to connect to"
}
