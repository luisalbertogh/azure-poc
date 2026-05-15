# =============================================================================
# COMMON CONFIGURATION: Storage
# =============================================================================
# Shared module source + default inputs for every environment's storage unit.
# Environment-specific overrides are provided in the calling unit's
# terragrunt.hcl (e.g. environments/dev/spaincentral/storage/terragrunt.hcl).
# =============================================================================

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment    = local.env_vars.locals.environment
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
}

# Path is from where the unit is located (e.g. /environments/dev/<region>/storage)
terraform {
  source = "../../../../catalog//tf-modules/storage"
}

inputs = {
  location    = local.location
  environment = local.environment
}
