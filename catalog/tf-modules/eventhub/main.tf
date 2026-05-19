# ==============================================================================
# Event Hubs Namespace
# ------------------------------------------------------------------------------
# Standard SKU is required because:
#   - Basic does not support managed-identity delivery from Event Grid
#   - Standard allows up to 10 consumer groups per hub
#
# Security hardening:
#   - local_authentication_enabled = false → SAS key auth disabled; all
#     data-plane access must use Entra ID (managed identity / RBAC)
#   - minimum_tls_version = "1.2"
# ==============================================================================
resource "azurerm_eventhub_namespace" "main" {
  name                = "evhns-poc-${var.environment}"
  location            = var.location
  resource_group_name = var.rg_name
  sku                 = var.event_hub_namespace_sku
  capacity            = 1

  minimum_tls_version           = "1.2"
  local_authentication_enabled  = false
  public_network_access_enabled = true

  tags = var.tags
}

# ==============================================================================
# Event Hub – receives blob-created events forwarded by Event Grid
# ==============================================================================
resource "azurerm_eventhub" "images" {
  name              = "evh-images-${var.environment}"
  namespace_id      = azurerm_eventhub_namespace.main.id
  partition_count   = var.event_hub_partition_count
  message_retention = var.event_hub_message_retention
}

# ==============================================================================
# Consumer Group – dedicated group for the Azure Function consumer.
# Using a dedicated group ensures the function has its own offset tracking and
# does not interfere with other potential consumers (e.g. monitoring, auditing).
# ==============================================================================
resource "azurerm_eventhub_consumer_group" "function" {
  name                = "fn-consumer-${var.environment}"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.images.name
  resource_group_name = var.rg_name
}

# ==============================================================================
# Event Grid System Topic
# ------------------------------------------------------------------------------
# Sources events from the images storage account. A system-assigned managed
# identity is attached so Event Grid can authenticate to Event Hub via Entra
# ID when delivering events – no SAS tokens or connection strings required.
# ==============================================================================
resource "azurerm_eventgrid_system_topic" "storage" {
  name                   = "evgt-storage-${var.environment}"
  resource_group_name    = var.rg_name
  location               = var.location
  source_arm_resource_id = var.storage_account_id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ==============================================================================
# Role assignment – Event Grid system topic identity → Event Hub Data Sender
# ------------------------------------------------------------------------------
# Scoped to the specific Event Hub resource (principle of least privilege).
# The role must be in place before the Event Grid subscription is created;
# otherwise the delivery endpoint validation at subscription creation time fails.
# ==============================================================================
resource "azurerm_role_assignment" "eventgrid_evh_sender" {
  scope                = azurerm_eventhub.images.id
  role_definition_name = "Azure Event Hubs Data Sender"
  principal_id         = azurerm_eventgrid_system_topic.storage.identity[0].principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_eventgrid_system_topic.storage]
}

# ==============================================================================
# Event Grid Subscription – routes BlobCreated events to the Event Hub
# ------------------------------------------------------------------------------
# Filters:
#   - Event type  : Microsoft.Storage.BlobCreated only
#   - Subject     : blobs whose path begins with the images container prefix
#
# Delivery uses the system topic's system-assigned managed identity
# (delivery_identity block). The depends_on ensures the sender role assignment
# is committed before the subscription is provisioned, preventing delivery
# failures at creation time.
#
# Retry policy: up to 30 attempts over 24 hours (1 440 minutes).
# ==============================================================================
resource "azurerm_eventgrid_system_topic_event_subscription" "images_to_evh" {
  name                = "evgs-images-to-evh-${var.environment}"
  system_topic        = azurerm_eventgrid_system_topic.storage.name
  resource_group_name = var.rg_name

  eventhub_endpoint_id = azurerm_eventhub.images.id

  delivery_identity {
    type = "SystemAssigned"
  }

  included_event_types = ["Microsoft.Storage.BlobCreated"]

  subject_filter {
    # Match blobs uploaded anywhere inside the images container.
    subject_begins_with = "/blobServices/default/containers/${var.images_container_name}"
    case_sensitive      = false
  }

  retry_policy {
    max_delivery_attempts = 3
    event_time_to_live    = 60
  }

  depends_on = [azurerm_role_assignment.eventgrid_evh_sender]
}
