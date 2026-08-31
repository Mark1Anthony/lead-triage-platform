resource "azurerm_container_registry" "this" {
  # Registry names allow no separators at all.
  name                = "acr${var.name}${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"

  # Eight of Checkov's registry findings resolve to one decision: private
  # endpoints, geo-replication, zone redundancy, image quarantine, trust
  # policies, dedicated data endpoints and untagged-manifest retention are all
  # Premium-only. Premium is roughly ten times the price of Basic for a
  # registry holding one image, so this is a cost decision, not a security
  # oversight - and the one thing that actually protects the images, keeping
  # the admin account off and authenticating with identities, is done below.
  #checkov:skip=CKV_AZURE_139:Private networking requires Premium.
  #checkov:skip=CKV_AZURE_163:Defender image scanning requires Premium and a Defender plan; Trivy scans the image in the pipeline instead.
  #checkov:skip=CKV_AZURE_164:Content trust requires Premium.
  #checkov:skip=CKV_AZURE_165:Geo-replication requires Premium and there is one region.
  #checkov:skip=CKV_AZURE_166:Quarantine requires Premium.
  #checkov:skip=CKV_AZURE_167:Retention policies require Premium.
  #checkov:skip=CKV_AZURE_233:Zone redundancy requires Premium.
  #checkov:skip=CKV_AZURE_237:Dedicated data endpoints require Premium.

  # The admin account is a shared username and password that cannot be traced
  # to a person and cannot be scoped. Both AKS and CI authenticate with an
  # identity instead, so it stays off.
  admin_enabled = false

  tags = local.tags
}
