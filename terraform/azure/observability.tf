resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${local.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "PerGB2018"

  # Ingestion is billed per gigabyte and retention beyond this is billed again.
  # Thirty days answers "what happened last week" without paying to keep logs
  # nobody will read.
  retention_in_days = 30
  tags              = local.tags
}

resource "azurerm_monitor_action_group" "alerts" {
  count = var.budget_alert_email == "" ? 0 : 1

  name                = "ag-${local.prefix}"
  resource_group_name = azurerm_resource_group.this.name
  short_name          = "leadtriage"

  email_receiver {
    name          = "operator"
    email_address = var.budget_alert_email
  }

  tags = local.tags
}

# Azure enforces no spending limit on pay-as-you-go, so a budget is an alert
# and nothing more. It is here because the difference between a 20 EUR month
# and a 200 EUR month is usually noticing in week one.
resource "azurerm_consumption_budget_resource_group" "this" {
  count = var.budget_alert_email == "" ? 0 : 1

  name              = "budget-${local.prefix}"
  resource_group_id = azurerm_resource_group.this.id

  amount     = var.monthly_budget_eur
  time_grain = "Monthly"

  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", timestamp())
  }

  # Actual spend has already happened; forecast is the one that can still be
  # acted on. Both are wired up.
  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    threshold_type = "Actual"
    contact_emails = [var.budget_alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    threshold_type = "Forecasted"
    contact_emails = [var.budget_alert_email]
  }

  lifecycle {
    # start_date uses timestamp(), which changes on every plan. Without this
    # the budget would be proposed for replacement forever.
    ignore_changes = [time_period]
  }
}
