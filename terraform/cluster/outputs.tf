output "namespace" {
  description = "Namespace the platform is deployed into."
  value       = kubernetes_namespace.this.metadata[0].name
}

output "url" {
  description = "Where the application answers once the ingress controller is up."
  value       = "http://${var.ingress_host}"
}

output "api_token" {
  description = <<-EOT
    Shared secret for the write endpoints. Read it with
    `terraform output -raw api_token`; it is not printed by default.
  EOT
  value       = random_password.api_token.result
  sensitive   = true
}
