# ─── Key Vault ────────────────────────────────────────────────────

resource "azurerm_key_vault" "this" {
  name                = "kv-${local.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # RBAC rather than the older access policies: permissions are then granted
  # the same way as everywhere else in Azure, and show up in the same audit.
  enable_rbac_authorization = true

  # A deleted secret is recoverable for a week. Purge protection makes that
  # week non-negotiable, which is the point - it is what stops an accidental
  # or malicious delete from being final.
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  tags = local.tags
}

# Terraform runs as its own identity and needs to write the secret it composes.
resource "azurerm_role_assignment" "terraform_manages_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ─── The application's identity ───────────────────────────────────
#
# The pod gets a token from Entra ID by presenting its Kubernetes service
# account. No secret is mounted, nothing to rotate, nothing to leak.

resource "azurerm_user_assigned_identity" "app" {
  name                = "id-${local.prefix}-app"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "app" {
  name                = "kubernetes"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.app.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.this.oidc_issuer_url

  # Must match the namespace and service account the chart creates. A mismatch
  # here fails at runtime with a token error, not at apply time.
  subject = "system:serviceaccount:lead-triage:lead-triage"
}

resource "azurerm_role_assignment" "app_reads_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}

# ─── The pipeline's identity ──────────────────────────────────────
#
# GitHub Actions authenticates by exchanging its own workflow token for an
# Entra token. There is no client secret in the repository and none to expire.
# See docs/adr/0002-oidc-instead-of-secrets.md.

resource "azurerm_user_assigned_identity" "cicd" {
  name                = "id-${local.prefix}-cicd"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "cicd_main" {
  name                = "github-main"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.cicd.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"

  # Scoped to one branch of one repository. A workflow on a fork or a feature
  # branch presents a different subject and is refused.
  subject = "repo:${var.github_repository}:ref:refs/heads/main"
}

resource "azurerm_federated_identity_credential" "cicd_pull_request" {
  name                = "github-pull-request"
  resource_group_name = azurerm_resource_group.this.name
  parent_id           = azurerm_user_assigned_identity.cicd.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"

  # Pull requests get a separate credential so the plan job can read state
  # while the apply job, bound to main above, is the only one that can change
  # anything.
  subject = "repo:${var.github_repository}:pull_request"
}

resource "azurerm_role_assignment" "cicd_deploys" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.cicd.principal_id
}

resource "azurerm_role_assignment" "cicd_pushes_images" {
  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.cicd.principal_id
}
