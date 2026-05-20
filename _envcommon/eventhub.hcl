# =============================================================================
# COMMON CONFIGURATION: Event Hub
# =============================================================================
# Shared module source and default inputs for every environment's eventhub
# unit. Environment-specific overrides and dependency wiring are provided in
# the calling unit's terragrunt.hcl
# (e.g. environments/dev/spaincentral/eventhub/terragrunt.hcl).
# =============================================================================

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment    = local.env_vars.locals.environment
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
}

# Path is relative to the calling unit directory
# (e.g. /environments/dev/<region>/eventhub)
terraform {
  source = "../../../../catalog//tf-modules/eventhub"
}

inputs = {
  location    = local.location
  environment = local.environment
}
