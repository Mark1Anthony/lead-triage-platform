output "resource_group" {
  description = "Resource group holding the stack."
  value       = azurerm_resource_group.this.name
}

output "cluster_name" {
  description = "AKS cluster name, for `az aks get-credentials`."
  value       = azurerm_kubernetes_cluster.this.name
}

output "registry_login_server" {
  description = "Registry to tag images for."
  value       = azurerm_container_registry.this.login_server
}

output "database_fqdn" {
  description = "Private hostname of the database. Only resolvable inside the network."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "app_client_id" {
  description = "Client ID the workload identity annotation on the service account needs."
  value       = azurerm_user_assigned_identity.app.client_id
}

output "cicd_client_id" {
  description = <<-EOT
    Client ID for the GitHub login action. Not a secret - it identifies the
    identity, it does not authenticate as it. That is what the OIDC exchange
    is for.
  EOT
  value       = azurerm_user_assigned_identity.cicd.client_id
}

output "database_url_secret" {
  description = "Key Vault secret the cluster reads the connection string from."
  value       = azurerm_key_vault_secret.database_url.name
}
