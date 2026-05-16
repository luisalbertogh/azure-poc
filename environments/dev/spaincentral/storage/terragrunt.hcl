# =============================================================================
# UNIT: Storage – dev / spaincentral
# =============================================================================
# Deploys the storage account + private blob container + lifecycle policy
# into the resource group provisioned by the sibling networking unit.
# =============================================================================

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path           = find_in_parent_folders("_envcommon/storage.hcl")
  expose         = true
  merge_strategy = "deep"
}

# The storage account lives inside the RG owned by the networking unit, so we
# wire an explicit dependency to ensure ordering and to read the RG name from
# the upstream state rather than hard-coding it.
dependency "networking" {
  config_path = "../networking"

  mock_outputs = {
    resource_group_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-mock"
    resource_group_name     = "rg-mock"
    resource_group_location = "spaincentral"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init", "fmt"]
}

inputs = {
  rg_id    = dependency.networking.outputs.resource_group_id
  location = include.root.locals.region_vars.locals.location

  container_name           = "images"
  processed_prefix         = "processed/"
  processed_retention_days = 30

  tags = merge(
    include.root.locals.common_tags,
    {
      Project   = "POCs",
      Component = "Storage",
      CI        = "Azure Pipelines"
    }
  )
}
