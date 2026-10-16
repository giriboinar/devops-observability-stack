output "public_ip" {
  description = "Public IP of the observability host"
  value       = aws_instance.observability.public_ip
}

output "grafana_url" {
  description = "Grafana UI URL"
  value       = "http://${aws_instance.observability.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus UI URL"
  value       = "http://${aws_instance.observability.public_ip}:9090"
}
