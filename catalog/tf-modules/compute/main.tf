# ==============================================================================
# Storage Account – dedicated to the Azure Function runtime and deployment
# ------------------------------------------------------------------------------
# - Shared key access is disabled → all data plane operations use Entra ID
# - Public network access is allowed so the CI/CD pipeline can upload the
#   deployment package blob without needing VNet peering.
# - The function app identity is granted Storage Blob Data Owner, Storage
#   Queue Data Contributor, and Storage Table Data Contributor later in this
#   module so the runtime can operate without connection strings.
# ==============================================================================
resource "random_string" "fn_storage_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true

  keepers = {
    # Rotate the suffix only if the owning resource group changes
    rg_id = var.rg_id
  }
}

locals {
  fn_storage_account_name   = "stgfn${var.environment}${random_string.fn_storage_suffix.result}"
  deployment_container_name = "deploymentpackage"
}

module "fn_storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.6"

  name      = local.fn_storage_account_name
  parent_id = var.rg_id
  location  = var.location
  tags      = var.tags

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  min_tls_version                   = "TLS1_2"
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true

  # Allow Azure services (function runtime) and CI/CD uploads
  network_rules = {
    default_action = "Allow"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  enable_telemetry = false
}

# ==============================================================================
# Storage container – holds the function deployment package (zip blob)
# ==============================================================================
resource "azurerm_storage_container" "deployment" {
  name                  = local.deployment_container_name
  storage_account_id    = module.fn_storage_account.resource_id
  container_access_type = "private"
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
  storage_account_name   = module.fn_storage_account.name
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
  storage_container_endpoint  = "https://${module.fn_storage_account.name}.blob.core.windows.net/${azurerm_storage_container.deployment.name}"
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
    # Identity-based storage access (no connection strings, no shared keys)
    "AzureWebJobsStorage__accountName"    = module.fn_storage_account.name
    "AzureWebJobsStorage__blobServiceUri"  = "https://${module.fn_storage_account.name}.blob.core.windows.net"
    "AzureWebJobsStorage__queueServiceUri" = "https://${module.fn_storage_account.name}.queue.core.windows.net"
    "AzureWebJobsStorage__tableServiceUri" = "https://${module.fn_storage_account.name}.table.core.windows.net"
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
# Role assignments – function runtime storage account
# The system identity needs these three roles on its OWN storage account
# for the runtime to operate correctly (no connection strings).
# ==============================================================================
resource "azurerm_role_assignment" "fn_storage_blob_owner" {
  scope                = module.fn_storage_account.resource_id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "fn_storage_queue_contributor" {
  scope                = module.fn_storage_account.resource_id
  role_definition_name = "Storage Queue Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "fn_storage_table_contributor" {
  scope                = module.fn_storage_account.resource_id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_function_app_flex_consumption.main.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# ==============================================================================
# Role assignment – images storage account (provisioned by the storage unit)
# Storage Blob Data Contributor allows the function to read and write the
# images container without using shared key access.
# ==============================================================================
resource "azurerm_role_assignment" "fn_images_storage_contributor" {
  scope                = var.images_storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
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
