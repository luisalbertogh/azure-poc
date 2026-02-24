# =============================================================================
# UNIT: Networking – dev / westeurope
# =============================================================================
# This file is the live configuration for the networking unit in the DEV
# environment's West Europe region. It:
#   1. Includes root.hcl (provider + remote state)
#   2. Includes the shared _envcommon/networking.hcl (module source + defaults)
#   3. Provides environment-specific overrides via inputs {}
# =============================================================================

include "root" {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

include "envcommon" {
  path   = find_in_parent_folders("_envcommon/networking.hcl")
  expose = true
  merge_strategy = "deep"
}

inputs = {
  rg_name   = include.root.locals.env_vars.locals.rg_name
  location  = include.root.locals.region_vars.locals.location
  tags      = merge(
    include.root.locals.common_tags, 
    { Project = "POCs" }
  )
}
