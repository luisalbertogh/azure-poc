# =============================================================================
# ENVIRONMENT: dev
# =============================================================================
# Environment-level variables for the Development environment.
# This file is discovered automatically by find_in_parent_folders("env.hcl")
# in child unit configurations.
# =============================================================================

locals {
  environment = "dev"

  # ---------------------------------------------------------------------------
  # Azure Identity – populated via CI/CD pipeline variable group or repo secrets.
  # In local workflows these can be set as shell environment variables and
  # referenced here with get_env().
  # ---------------------------------------------------------------------------
  subscription_id = get_env("ARM_SUBSCRIPTION_ID", "00000000-0000-0000-0000-000000000000")
  tenant_id       = get_env("ARM_TENANT_ID",       "00000000-0000-0000-0000-000000000000")

  # The OIDC-enabled Service Principal / Workload Identity client ID for DEV.
  # The actual OIDC token (ARM_OIDC_TOKEN) is injected by the CI/CD runtime.
  client_id = get_env("ARM_CLIENT_ID", "00000000-0000-0000-0000-000000000000")

  # Networking address space for this environment
  vnet_address_space = "10.10.0.0/16"

  # Main Resource group name
  rg_name   = "rg-poc-dev"
}
