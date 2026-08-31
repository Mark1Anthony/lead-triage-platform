resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${local.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  dns_prefix          = local.prefix
  kubernetes_version  = var.kubernetes_version

  # Free tier: no uptime SLA on the control plane, no charge for it either.
  # A paid tier buys an SLA, not capability.
  sku_tier = "Free"

  # Local accounts off means every kubectl call is authenticated through Entra
  # ID, so access is revoked by removing a person from a group rather than by
  # hoping a downloaded kubeconfig is gone.
  local_account_disabled    = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
  }

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_size
    vnet_subnet_id = azurerm_subnet.nodes.id

    upgrade_settings {
      # Add one node before taking one out, so capacity never dips during an
      # upgrade.
      max_surge = "1"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    service_cidr   = "10.1.0.0/16"
    dns_service_ip = "10.1.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  # Lets pods obtain Entra tokens without any secret in the cluster - the same
  # mechanism the GitHub pipeline uses to reach Azure.
  workload_identity_enabled = true
  oidc_issuer_enabled       = true

  tags = local.tags

  lifecycle {
    ignore_changes = [
      # The autoscaler owns this once it is on; Terraform must not reset it to
      # the value in the variable on the next apply.
      default_node_pool[0].node_count,
    ]
  }
}

# Pulling from the registry is a role assignment, not a stored credential.
resource "azurerm_role_assignment" "aks_pulls_images" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}
