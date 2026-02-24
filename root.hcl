# =============================================================================
# ROOT TERRAGRUNT CONFIGURATION
# =============================================================================
# This is the root configuration file for the entire Terragrunt project.
# All child units include this file via find_in_parent_folders("root.hcl").
#
# Responsibilities:
#   - Azure provider generation with OIDC authentication
#   - Remote state backend (Azure Storage Account)
#   - Common tags and locals shared across all environments
# =============================================================================

# ---------------------------------------------------------------------------
# Local values: resolved from the environment-specific env.hcl and region.hcl
# files that sit in each environment directory. These are merged and made
# available to every child unit through this root configuration.
# ---------------------------------------------------------------------------
locals {
  # Load the environment-level variables (env name, subscription ID, etc.)
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Load the region-level variables (Azure region, etc.)
  region_vars = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  # Convenience aliases
  environment     = local.env_vars.locals.environment
  subscription_id = local.env_vars.locals.subscription_id
  tenant_id       = local.env_vars.locals.tenant_id
  client_id       = local.env_vars.locals.client_id   # OIDC: Service Principal / Managed Identity App ID
  location        = local.region_vars.locals.location

  # Remote state storage (shared Azure Storage Account – must be pre-provisioned)
  tf_state_resource_group  = "cicd"
  tf_state_storage_account = "stgterraformlagh"
  tf_state_container       = "tfstate"

  # Common tags for all resources
  common_tags = {
    Environment = local.environment
    ManagedBy   = "Terragrunt"
    Usage       = "Azure POC"
  }
}

# ---------------------------------------------------------------------------
# Remote state: Azure Storage Account backend
# The state key is automatically derived from the directory path of the calling
# unit relative to this root file, guaranteeing unique state per unit.
# ---------------------------------------------------------------------------
# generate "backend" {
#   path      = "backend.tf"
#   if_exists = "overwrite_terragrunt"
#   contents = <<EOF
# # This is configuration for GitHub actions - See https://developer.hashicorp.com/terraform/language/backend/azurerm
# terraform {
#   backend "azurerm" {
#     use_oidc             = true                                                 # Can also be set via `ARM_USE_OIDC` environment variable.
#     use_azuread_auth     = true                                                 # Can also be set via `ARM_USE_AZUREAD` environment variable.
#     tenant_id            = "${local.tenant_id}"                                 # Can also be set via `ARM_TENANT_ID` environment variable.
#     client_id            = "${local.client_id}"                                 # Can also be set via `ARM_CLIENT_ID` environment variable.
#     storage_account_name = "${local.tf_state_storage_account}"                  # Can also be set via `ARM_STORAGE_ACCOUNT_NAME` environment variable.
#     container_name       = "${local.tf_state_container}"                        # Can also be set via `ARM_CONTAINER_NAME` environment variable.
#     key                  = "${path_relative_to_include()}/terraform.tfstate"    # Can also be set via `ARM_KEY` environment variable.
#   }
# }
# EOF
# }

# Local backend
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<EOF
terraform {
  backend "azurerm" {
    use_oidc             = true                               
    use_azuread_auth     = true
    tenant_id            = "${local.tenant_id}"
    client_id            = "${local.client_id}"
    storage_account_name = "${local.tf_state_storage_account}"                    
    container_name       = "${local.tf_state_container}"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
  }
}
EOF
}

# ---------------------------------------------------------------------------
# Azure Provider: generated into every unit's working directory.
# OIDC authentication is configured via environment variables that are
# expected to be set by the CI/CD pipeline (see docs/terragrunt-guide.md):
#   ARM_CLIENT_ID       – Service Principal / Workload Identity client ID
#   ARM_TENANT_ID       – Azure AD tenant ID
#   ARM_SUBSCRIPTION_ID – Target subscription ID
#   ARM_USE_OIDC        – Must be "true"
#   ARM_OIDC_TOKEN      – OIDC token provided by the CI/CD runtime
# ---------------------------------------------------------------------------
generate "provider_azure" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOF
    terraform {
      required_version = ">= 1.9"

      required_providers {
        azurerm = {
          source  = "hashicorp/azurerm"
          version = "~> 4.0"
        }
        azapi = {
          source  = "Azure/azapi"
          version = "~> 2.4"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.5"
        }
      }
    }

    # Authentication relies entirely on environment variables injected by the
    # CI/CD pipeline. No secrets are stored in code.
    # ARM_USE_OIDC=true + ARM_OIDC_TOKEN triggers OIDC (federated credential) auth.
    provider "azurerm" {
      
      # Enforce Azure AD authentication over Shared Key for provisioning Storage Containers, Blobs, and other items.
      storage_use_azuread = true
      
      # Used for authentication to Azure for resource provisioning. Can be set via environment variables for CI/CD or local development.
      subscription_id = "${local.subscription_id}"
      tenant_id       = "${local.tenant_id}"
      client_id       = "${local.client_id}"

      # Use OpenID Connect / Workload identity federation authentication for authentication to the storage account management and data plane
      # ARM_OIDC_TOKEN env var supplies the token at runtime
      use_oidc = true   

      # Allow using a Managed Identity if available (e.g. in local dev with Azure CLI logged in, or in CI/CD with a federated credential)
      use_msi = true   

      features {
        # Do not destroy azurerm_key_vault resources after deletion and allow recovery.
        key_vault {
          purge_soft_delete_on_destroy    = false
          recover_soft_deleted_key_vaults = true
        }
        # Ensure resource_group resources are fully removed before deleting the resource group.
        resource_group {
          prevent_deletion_if_contains_resources = true
        }
      }
    }

    provider "azuread" {
      tenant_id = "${local.tenant_id}"
      client_id = "${local.client_id}"
      
      use_oidc  = true
      
      # Allow using a Managed Identity if available (e.g. in local dev with Azure CLI logged in, or in CI/CD with a federated credential)
      use_msi = true
    }
  EOF
}

# ---------------------------------------------------------------------------
# Common inputs: injected into every unit automatically.
# Units can override these values in their own inputs block.
# ---------------------------------------------------------------------------
inputs = {
  environment = local.environment
  location    = local.location
}
