resource "azurerm_resource_group" "kanwa-rg" {
  name     = "${var.env}-kanwa-rg"
  location = var.resource_group_location
}

resource "azurerm_application_insights" "kanwa-ai" {
  name                = "${var.env}-kanwa-ai"
  location            = azurerm_resource_group.kanwa-rg.location
  resource_group_name = azurerm_resource_group.kanwa-rg.name
  application_type    = "web"
  retention_in_days   = 90
  workspace_id        = azurerm_log_analytics_workspace.kanwa-law.id
}

resource "azurerm_log_analytics_workspace" "kanwa-law" {
  name                = "${var.env}-kanwa-law"
  location            = azurerm_resource_group.kanwa-rg.location
  resource_group_name = azurerm_resource_group.kanwa-rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "kanwa-env" {
  count               = var.env == "prod" ? 1 : 0
  name                = "${var.env}-kanwa-ca-env"
  location            = azurerm_resource_group.kanwa-rg.location
  resource_group_name = azurerm_resource_group.kanwa-rg.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.kanwa-law.id
}

resource "azurerm_container_app" "kanwa-app" {
  count                        = var.env == "prod" ? 1 : 0
  name                         = "${var.env}-kanwa-app"
  container_app_environment_id = azurerm_container_app_environment.kanwa-env.id
  resource_group_name          = azurerm_resource_group.kanwa-rg.name
  revision_mode                = "Single"

  template {
    container {
      name   = "kanwa-container"
      image  = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
      cpu    = 0.25
      memory = "0.5Gi"
    }

    scale {
      min_replicas = 1
      max_replicas = 3
    }
  }

  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "auto"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_server" "kanwa-database" {
  count                        = var.env == "prod" ? 1 : 0
  name                         = "${var.env}-kanwa-database"
  resource_group_name          = azurerm_resource_group.kanwa-rg.name
  location                     = azurerm_resource_group.kanwa-rg.location
  version                      = "12.0"
  administrator_login          = var.sql_login
  administrator_login_password = var.sql_password
}

resource "azurerm_mssql_database" "kanwa" {
  count        = var.env == "prod" ? 1 : 0
  name         = "kanwa"
  server_id    = azurerm_mssql_server.kanwa-database.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "Basic"
}