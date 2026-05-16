# ==============================================================================
# Suffix – stable random string for unique resource names (Log Analytics,
# Application Insights). Keyed to the resource group so it only rotates if
# the owning resource group is replaced.
# ==============================================================================
resource "random_string" "fn_storage_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true

  keepers = {
    rg_id = var.rg_id
  }
}

locals {
  # The deployment package container lives inside the shared images storage
  # account (provided by the storage unit dependency). No dedicated function
  # storage account is created – the function runtime re-uses the same account.
  deployment_container_name = "deploymentpackage"
}

# ==============================================================================
# Current Terraform runner identity
# Used to grant the pipeline service principal data-plane access on the storage
# account. Required because shared_access_key_enabled = false on the account,
# so ALL data-plane operations (container create, blob upload) must use OAuth.
# Without this role assignment the provider gets 403 when it tries to check or
# write the deployment zip blob.
# ==============================================================================
data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "deployer_blob_contributor" {
  scope                = var.images_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
  principal_type       = "ServicePrincipal"
}

# ==============================================================================
# Storage container – holds the function deployment package (zip blob)
# ==============================================================================
resource "azurerm_storage_container" "deployment" {
  name                  = local.deployment_container_name
  storage_account_id    = var.images_storage_account_id
  container_access_type = "private"

  depends_on = [azurerm_role_assignment.deployer_blob_contributor]
}

# ==============================================================================
# Hello World function source – packaged as a zip and uploaded to the
# deployment container. The function app reads the package from there using
# its system-assigned managed identity.
# ==============================================================================
data "archive_file" "hello_world" {
  type        = "zip"
  source_dir  = "${path.module}/function-src"
  output_path = "${path.module}/.tmp/function-src.zip"
}

resource "azurerm_storage_blob" "function_package" {
  name                   = "function-src.zip"
  storage_account_name   = var.images_storage_account_name
  storage_container_name = azurerm_storage_container.deployment.name
  type                   = "Block"
  source                 = data.archive_file.hello_world.output_path
  content_md5            = data.archive_file.hello_world.output_md5
}

# ==============================================================================
# Log Analytics Workspace – required by Application Insights
# ==============================================================================
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-fn-${var.environment}-${random_string.fn_storage_suffix.result}"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ==============================================================================
# Application Insights – telemetry for the function app
# ==============================================================================
resource "azurerm_application_insights" "main" {
  name                = "appi-fn-${var.environment}-${random_string.fn_storage_suffix.result}"
  location            = var.location
  resource_group_name = var.rg_name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = var.tags
}

# ==============================================================================
# Service Plan – Flex Consumption (FC1, Linux)
# Flex Consumption is a pay-per-use serverless plan with:
#   - Per-function scaling and concurrency control
#   - Virtual network support and private endpoint support
#   - Managed identity for storage auth (no connection strings required)
# Only one function app per Flex Consumption plan is supported.
# ==============================================================================
resource "azurerm_service_plan" "main" {
  name                = "plan-fn-${var.environment}"
  location            = var.location
  resource_group_name = var.rg_name
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = var.tags
}

# ==============================================================================
# Function App – Flex Consumption, Python 3.11, private-only
# ------------------------------------------------------------------------------
# Security hardening:
#   - public_network_access_enabled = false → function only reachable via
#     the private endpoint created below
#   - https_only = true
#   - ip_restriction_default_action = "Deny" (defense-in-depth)
#   - storage_authentication_type = "SystemAssignedIdentity" → no shared keys
#   - webdeploy_publish_basic_authentication_enabled = false
#
# Networking:
#   - virtual_network_subnet_id → VNet integration for all outbound traffic
#     (subnet delegated to Microsoft.App/environments)
#   - Private endpoint (inbound) is configured below
#
# NOTE: The Microsoft.App resource provider must be registered in the
# subscription before the VNet subnet delegation will succeed.
# Register it with: az provider register --namespace Microsoft.App
# ==============================================================================
resource "azurerm_function_app_flex_consumption" "main" {
  name                = "fn-poc-${var.environment}"
  location            = var.location
  resource_group_name = var.rg_name
  service_plan_id     = azurerm_service_plan.main.id

  # The function runtime reads its code package from this container
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "https://${var.images_storage_account_name}.blob.core.windows.net/${azurerm_storage_container.deployment.name}"
  storage_authentication_type = "SystemAssignedIdentity"

  runtime_name    = "python"
  runtime_version = "3.11"

  maximum_instance_count = var.maximum_instance_count
  instance_memory_in_mb  = var.instance_memory_in_mb

  # System-assigned managed identity used for all downstream access
  identity {
    type = "SystemAssigned"
  }

  # Disable all public HTTP access – function is reachable only via private endpoint
  public_network_access_enabled                = false
  https_only                                   = true
  webdeploy_publish_basic_authentication_enabled = false

  # Route all outbound traffic through the VNet (subnet delegated to Microsoft.App/environments)
  virtual_network_subnet_id = var.functions_subnet_id

  site_config {
    application_insights_connection_string = azurerm_application_insights.main.connection_string
    vnet_route_all_enabled                 = true
    minimum_tls_version                    = "1.2"
    ip_restriction_default_action          = "Deny"
    scm_ip_restriction_default_action      = "Deny"
  }

  app_settings = {
    # Identity-based storage access – re-uses the shared images storage account
    # (no dedicated function storage account, no connection strings or shared keys)
    "AzureWebJobsStorage__accountName"    = var.images_storage_account_name
    "AzureWebJobsStorage__blobServiceUri"  = "https://${var.images_storage_account_name}.blob.core.windows.net"
    "AzureWebJobsStorage__queueServiceUri" = "https://${var.images_storage_account_name}.queue.core.windows.net"
    "AzureWebJobsStorage__tableServiceUri" = "https://${var.images_storage_account_name}.table.core.windows.net"
    "AzureWebJobsStorage__credential"      = "managedidentity"

    # Images storage account (set by the storage unit dependency)
    "IMAGES_STORAGE_ACCOUNT_NAME" = var.images_storage_account_name
    "IMAGES_CONTAINER_NAME"       = var.images_container_name

    # Cosmos DB endpoint (optional – set when Cosmos DB is provisioned)
    "COSMOS_DB_ACCOUNT_URI" = var.cosmos_db_account_uri

    # Azure AI Foundry Content Understanding endpoint (optional)
    "CONTENT_UNDERSTANDING_ENDPOINT" = var.foundry_content_understanding_endpoint
  }

  tags = var.tags

  depends_on = [
    azurerm_storage_container.deployment,
    azurerm_storage_blob.function_package,
  ]
}

# ==============================================================================
# Role assignments – shared storage account (images + function runtime)
# The function runtime re-uses the images storage account for its internal
# state (host ID, trigger leases, deployment package container). Three roles
# are required for the runtime to operate without connection strings.
# NOTE: Storage Blob Data Owner is intentionally elevated vs Contributor –
# the Azure Functions runtime requires it to manage host lease blobs.
# ==============================================================================
resource "azurerm_role_assignment" "fn_storage_blob_owner" {
  scope                = var.images_storage_account_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "fn_storage_queue_contributor" {
  scope                = var.images_storage_account_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "fn_storage_table_contributor" {
  scope                = var.images_storage_account_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# ==============================================================================
# Role assignment – Cosmos DB (data-plane RBAC via azapi)
# Azure Cosmos DB data-plane access uses its own RBAC system, separate from
# Azure control-plane RBAC. The built-in role
#   "Cosmos DB Built-in Data Contributor" (id: 00000000-0000-0000-0000-000000000002)
# grants read/write access to all databases and containers in the account.
#
# The assignment name is derived deterministically from the account ID to avoid
# conflicts across re-applies while remaining stable.
# ==============================================================================
resource "random_uuid" "cosmos_role_assignment" {
  count = var.cosmos_db_account_id != "" ? 1 : 0

  keepers = {
    cosmos_db_account_id = var.cosmos_db_account_id
  }
}

resource "azapi_resource" "cosmos_role_assignment" {
  count     = var.cosmos_db_account_id != "" ? 1 : 0
  type      = "Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-04-15"
  name      = random_uuid.cosmos_role_assignment[0].result
  parent_id = var.cosmos_db_account_id

  body = {
    properties = {
      principalId      = azurerm_function_app_flex_consumption.main.identity[0].principal_id
      roleDefinitionId = "${var.cosmos_db_account_id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
      scope            = var.cosmos_db_account_id
    }
  }
}

# ==============================================================================
# Role assignment – Azure AI Foundry / Content Understanding
# "Cognitive Services User" allows the function identity to call the
# Content Understanding API hosted on the Azure AI Foundry resource.
# ==============================================================================
resource "azurerm_role_assignment" "fn_foundry_user" {
  count                = var.foundry_account_id != "" ? 1 : 0
  scope                = var.foundry_account_id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# ==============================================================================
# Private DNS Zone – resolves the function app's hostname inside the VNet
# Required so resources within the VNet can resolve the private endpoint IP.
# ==============================================================================
resource "azurerm_private_dns_zone" "fn_app" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = var.rg_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "fn_app" {
  name                  = "pdnszl-fn-${var.environment}"
  resource_group_name   = var.rg_name
  private_dns_zone_name = azurerm_private_dns_zone.fn_app.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# ==============================================================================
# Private Endpoint – inbound access to the function app
# Placing the endpoint in the dedicated private-endpoints subnet (no service
# delegation required). The DNS zone group auto-registers the A record so
# name resolution inside the VNet resolves to the private IP.
# ==============================================================================
resource "azurerm_private_endpoint" "fn_app" {
  name                = "pe-fn-poc-${var.environment}"
  location            = var.location
  resource_group_name = var.rg_name
  subnet_id           = var.private_endpoints_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-fn-poc-${var.environment}"
    private_connection_resource_id = azurerm_function_app_flex_consumption.main.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-fn"
    private_dns_zone_ids = [azurerm_private_dns_zone.fn_app.id]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.fn_app]
}
