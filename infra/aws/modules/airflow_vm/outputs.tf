output "instance_id" {
  description = "ID de la instancia EC2 de Airflow."
  value       = aws_instance.airflow.id
}

output "public_ip" {
  description = "Elastic IP de la VM."
  value       = aws_eip.airflow.public_ip
}

output "url" {
  description = "URL de la UI de Airflow (HTTP, solo desde allowed_cidrs)."
  value       = "http://${aws_eip.airflow.public_ip}:8080"
}

output "secret_name" {
  description = "Nombre del secreto con las credenciales admin de Airflow."
  value       = aws_secretsmanager_secret.admin.name
}
