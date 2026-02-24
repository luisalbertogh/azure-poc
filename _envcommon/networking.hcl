# =============================================================================
# COMMON CONFIGURATION: Networking
# =============================================================================
# This file lives in _envcommon/ and is included by every environment's
# networking unit. It centralises the source reference and common inputs,
# while environment-specific overrides are provided by the caller.
#
# Usage in an environment unit (e.g. environments/dev/westeurope/networking/terragrunt.hcl):
#
#   include "root"    { path = find_in_parent_folders("root.hcl") }
#   include "envcommon" { path = find_in_parent_folders("_envcommon/networking.hcl") }
#
#   inputs = {
#     vnet_address_space = "10.10.0.0/16"
#   }
# =============================================================================

locals {
  env_vars    = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  environment    = local.env_vars.locals.environment
  location       = local.region_vars.locals.location
  location_short = local.region_vars.locals.location_short
}

# Remote Terraform module – pinned to a specific tag for reproducibility
terraform {
  #source = "git::https://github.com/myorg/terraform-azure-modules.git//modules/networking?ref=v1.3.0"
  source = "../../../../catalog//tf-modules/networking"  # Path is from where the unit is located (/networking)
}

inputs = {
  location            = local.location
  environment         = local.environment
}
