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

  # Already private: the server has no public endpoint, it joins the delegated
  # subnet and resolves through the private zone. Checkov looks for a private
  # endpoint resource and does not recognise VNet integration, which reaches
  # the same result by a different mechanism.
  #checkov:skip=CKV2_AZURE_57:Private through VNet integration - see delegated_subnet_id below.
  #checkov:skip=CKV_AZURE_136:Geo-redundant backups require a General Purpose tier; this runs on Burstable.

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

  # A secret with no expiry is one nobody revisits. A year is long enough not
  # to be busywork, short enough that a forgotten credential surfaces while
  # someone still remembers what it was for.
  # Says what the value is without revealing it, so an operator browsing the
  # vault does not have to read a secret to find out what it is for.
  content_type = "PostgreSQL connection URI"

  expiration_date = timeadd(timestamp(), "8760h")

  lifecycle {
    # timestamp() moves on every plan; without this the secret would be
    # proposed for replacement forever.
    ignore_changes = [expiration_date]
  }

  depends_on = [azurerm_role_assignment.terraform_manages_secrets]
}
