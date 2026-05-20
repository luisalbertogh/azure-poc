# =============================================================================
# UNIT: Compute – dev / spaincentral
# =============================================================================
# Deploys the Azure Function App (Flex Consumption, Python), its dedicated
# storage account, Application Insights, and the private endpoint that makes
# the function reachable only from within the private VNet.
#
# Dependencies:
#   - networking : provides the resource group, VNet ID, subnet IDs
#   - storage    : provides the images storage account ID and container name
#   - eventhub   : provides the Event Hub namespace FQDN, hub name, consumer
#                  group, and hub resource ID for the Event Hub trigger
#
# Optional inputs (set when the corresponding resources are created):
#   - cosmos_db_account_id / cosmos_db_account_uri
#   - foundry_account_id / foundry_content_understanding_endpoint
# =============================================================================

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path           = find_in_parent_folders("_envcommon/compute.hcl")
  expose         = true
  merge_strategy = "deep"
}

# ---------------------------------------------------------------------------
# Networking dependency – resource group, VNet, and subnets
# ---------------------------------------------------------------------------
dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock"
    resource_group_name         = "rg-mock"
    resource_group_location     = "spaincentral"
    vnet_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock"
    functions_subnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock/subnets/snet-functions"
    private_endpoints_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Network/virtualNetworks/vnet-mock/subnets/snet-pe"
  }
  mock_outputs_allowed_terraform_commands  = ["validate", "plan", "init", "fmt"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# ---------------------------------------------------------------------------
# Storage dependency – images storage account and container
# ---------------------------------------------------------------------------
dependency "storage" {
  config_path = "../storage"

  mock_outputs = {
    storage_account_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Storage/storageAccounts/stgmock"
    storage_account_name = "stgmock"
    container_name       = "images"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "fmt"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# ---------------------------------------------------------------------------
# Event Hub dependency – namespace FQDN, hub name, and consumer group used
# to configure the function app's Event Hub trigger (identity-based, no SAS).
# Apply the eventhub unit first, then re-apply compute to activate the trigger.
# ---------------------------------------------------------------------------
dependency "eventhub" {
  config_path = "../eventhub"

  mock_outputs = {
    eventhub_namespace_fqdn      = "evhns-poc-mock.servicebus.windows.net"
    eventhub_name                = "evh-images-mock"
    eventhub_consumer_group_name = "fn-consumer-mock"
    eventhub_id                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.EventHub/namespaces/evhns-mock/eventhubs/evh-images-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "fmt"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  rg_id    = dependency.networking.outputs.resource_group_id
  rg_name  = dependency.networking.outputs.resource_group_name
  location = include.root.locals.region_vars.locals.location

  # Networking
  vnet_id                     = dependency.networking.outputs.vnet_id
  functions_subnet_id         = dependency.networking.outputs.functions_subnet_id
  private_endpoints_subnet_id = dependency.networking.outputs.private_endpoints_subnet_id

  # Images storage (from the storage unit)
  images_storage_account_id   = dependency.storage.outputs.storage_account_id
  images_storage_account_name = dependency.storage.outputs.storage_account_name
  images_container_name       = dependency.storage.outputs.container_name

  # Event Hub (from the eventhub unit) – identity-based trigger, no SAS
  event_hub_namespace_fqdn = dependency.eventhub.outputs.eventhub_namespace_fqdn
  event_hub_name           = dependency.eventhub.outputs.eventhub_name
  event_hub_consumer_group = dependency.eventhub.outputs.eventhub_consumer_group_name
  event_hub_id             = dependency.eventhub.outputs.eventhub_id

  # ---------------------------------------------------------------------------
  # Cosmos DB – uncomment and populate when the Cosmos DB unit is provisioned
  # ---------------------------------------------------------------------------
  # cosmos_db_account_id  = "<cosmos-db-resource-id>"
  # cosmos_db_account_uri = "https://<account-name>.documents.azure.com:443/"

  # ---------------------------------------------------------------------------
  # Azure AI Foundry – uncomment and populate when the resource is provisioned
  # ---------------------------------------------------------------------------
  # foundry_account_id                      = "<ai-foundry-resource-id>"
  # foundry_content_understanding_endpoint  = "https://<resource-name>.cognitiveservices.azure.com/"

  tags = merge(
    include.root.locals.common_tags,
    {
      Project   = "POCs",
      Component = "Compute",
      CI        = "Azure Pipelines"
    }
  )
}
