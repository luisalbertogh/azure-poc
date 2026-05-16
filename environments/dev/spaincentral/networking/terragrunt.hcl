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
  path           = find_in_parent_folders("_envcommon/networking.hcl")
  expose         = true
  merge_strategy = "deep"
}

inputs = {
  rg_name  = include.root.locals.env_vars.locals.rg_name
  location = include.root.locals.region_vars.locals.location

  # Virtual network address space – sourced from env.hcl
  vnet_address_space = include.root.locals.env_vars.locals.vnet_address_space

  # Subnet CIDRs – carved from the VNet address space (10.10.0.0/16)
  functions_subnet_prefix         = "10.10.1.0/26"
  private_endpoints_subnet_prefix = "10.10.2.0/27"

  tags = merge(
    include.root.locals.common_tags,
    { Project   = "POCs",
      Component = "Networking"
      CI        = "Azure Pipelinesss"
    }
  )
}
