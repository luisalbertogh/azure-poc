# =============================================================================
# UNIT: Event Hub – dev / spaincentral
# =============================================================================
# Provisions the Event Hubs Namespace, Event Hub, dedicated consumer group,
# and the Event Grid plumbing (system topic + subscription) that routes
# BlobCreated events from the "images" container to the Event Hub.
#
# Dependencies:
#   - networking : provides the resource group
#   - storage    : provides the images storage account ID (Event Grid source)
#                  and the images container name (subject filter)
#
# The compute unit depends on this unit (not the other way around) so that
# the function app can be configured with the Event Hub connection settings
# after this unit is applied. No circular dependency exists.
# =============================================================================

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path           = find_in_parent_folders("_envcommon/eventhub.hcl")
  expose         = true
  merge_strategy = "deep"
}

# ---------------------------------------------------------------------------
# Networking dependency – resource group
# ---------------------------------------------------------------------------
dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock"
    resource_group_name     = "rg-mock"
    resource_group_location = "spaincentral"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "fmt"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

# ---------------------------------------------------------------------------
# Storage dependency – images storage account (Event Grid System Topic source)
# ---------------------------------------------------------------------------
dependency "storage" {
  config_path = "../storage"

  mock_outputs = {
    storage_account_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock/providers/Microsoft.Storage/storageAccounts/stgmock"
    container_name     = "images"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init", "fmt"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

inputs = {
  rg_id    = dependency.networking.outputs.resource_group_id
  rg_name  = dependency.networking.outputs.resource_group_name
  location = include.root.locals.region_vars.locals.location

  # Event Grid System Topic source – the images storage account
  storage_account_id    = dependency.storage.outputs.storage_account_id
  images_container_name = dependency.storage.outputs.container_name

  tags = merge(
    include.root.locals.common_tags,
    {
      Project   = "POCs",
      Component = "EventHub",
      CI        = "Azure Pipelines"
    }
  )
}
