resource "azurerm_container_registry" "this" {
  # Registry names allow no separators at all.
  name                = "acr${var.name}${var.environment}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"

  # The admin account is a shared username and password that cannot be traced
  # to a person and cannot be scoped. Both AKS and CI authenticate with an
  # identity instead, so it stays off.
  admin_enabled = false

  tags = local.tags
}
