resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${local.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  dns_prefix          = local.prefix
  kubernetes_version  = var.kubernetes_version

  # Deliberate deviations from the security baseline, each one a cost or a
  # reachability trade rather than an oversight. docs/adr/0004 explains the
  # rule: fix what has no downside, and justify what does - in the file, where
  # the next reader is already looking.
  #checkov:skip=CKV_AZURE_170:Free tier has no control-plane SLA. A paid tier buys an SLA, not capability, and this is a demonstration workload.
  #checkov:skip=CKV_AZURE_115:A private API server cannot be reached by a GitHub-hosted runner. Production would move the pipeline onto a self-hosted runner inside the VNet; that is a larger change than this repository carries.
  #checkov:skip=CKV_AZURE_6:Authorized IP ranges would have to list GitHub's runner ranges, which change without notice. Same answer as above - the fix is a runner in the VNet, not an allowlist that silently rots.
  #checkov:skip=CKV_AZURE_227:Host encryption must be enabled on the subscription first and is not supported on every VM size. Left off rather than written and untested.
  #checkov:skip=CKV_AZURE_117:Customer-managed disk encryption needs a key and a rotation process to be worth anything. Platform-managed keys are used instead.
  #checkov:skip=CKV_AZURE_226:Ephemeral OS disks need a VM size whose cache is large enough to hold the image. Standard_B2s is not.
  #checkov:skip=CKV_AZURE_232:Reserving the system pool for critical add-ons requires a second, user node pool. That doubles the node bill for one workload.

  # Free tier: no uptime SLA on the control plane, no charge for it either.
  # A paid tier buys an SLA, not capability.
  sku_tier = "Free"

  # Patch releases install themselves; minor upgrades stay a decision. CVEs in
  # the node image are the common case, and waiting for someone to notice them
  # is worse than an unplanned restart within the maintenance window.
  automatic_upgrade_channel = "patch"

  # Enforces pod-level policy - no privileged containers, no host mounts - at
  # admission, so a chart cannot opt out of it the way it can opt out of its
  # own securityContext.
  azure_policy_enabled = true

  # Local accounts off means every kubectl call is authenticated through Entra
  # ID, so access is revoked by removing a person from a group rather than by
  # hoping a downloaded kubeconfig is gone.
  local_account_disabled            = true
  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
  }

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_size
    vnet_subnet_id = azurerm_subnet.nodes.id

    # Azure CNI takes one subnet address per pod, so this is also what sizes
    # snet-nodes: 3 nodes x 50 pods fits comfortably in a /22.
    max_pods = 50

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

  # Mounts Key Vault secrets into pods as files and re-reads them on a timer,
  # so a rotated secret reaches the workload without a redeploy.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "5m"
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
