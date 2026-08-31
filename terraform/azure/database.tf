resource "random_password" "postgres" {
  length  = 32
  special = true
  # Azure rejects these three in an administrator password.
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                = "psql-${local.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location

  version    = "16"
  sku_name   = var.postgres_sku
  storage_mb = 32768

  administrator_login    = "leads"
  administrator_password = random_password.postgres.result

  # No public endpoint: the server joins the delegated subnet and is resolved
  # through the private zone. There is no firewall rule to get wrong.
  delegated_subnet_id = azurerm_subnet.database.id
  private_dns_zone_id = azurerm_private_dns_zone.postgres.id

  backup_retention_days = 7

  # A second zone doubles the price and this is a demo workload.
  zone = "1"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]

  tags = local.tags
}

resource "azurerm_postgresql_flexible_server_database" "leads" {
  name      = "leads"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# The connection string is assembled once and stored where the cluster can read
# it, so the password never leaves Azure and never appears in a pipeline log.
resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  key_vault_id = azurerm_key_vault.this.id

  value = format(
    "postgresql://%s:%s@%s:5432/%s?sslmode=require",
    azurerm_postgresql_flexible_server.this.administrator_login,
    urlencode(random_password.postgres.result),
    azurerm_postgresql_flexible_server.this.fqdn,
    azurerm_postgresql_flexible_server_database.leads.name,
  )

  depends_on = [azurerm_role_assignment.terraform_manages_secrets]
}
