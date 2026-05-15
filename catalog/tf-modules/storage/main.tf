# ==============================================================================
# Storage Account + private blob container + lifecycle policy
# ------------------------------------------------------------------------------
# - Storage account is locked down for public/anonymous use:
#     * Shared access keys disabled  -> all data plane access must use Entra ID
#     * Anonymous blob access disabled
#     * TLS 1.2 minimum, infrastructure encryption enabled
#     * Network rules allow public network reachability but only authenticated
#       AAD callers can do anything (portal/CLI uploads still work).
# - One private container is created (var.container_name).
# - A management policy deletes blobs under "<container>/<processed_prefix>"
#   after var.processed_retention_days days since last modification.
# ==============================================================================

locals {
  # Storage account names: 3-24 chars, lowercase alphanumeric, globally unique.
  # Pattern: "stgpoc" (6) + environment (<=6) + random suffix (6) <= 18-24.
  storage_account_name = "stgpoc${var.environment}${random_string.storage_suffix.result}"

  processed_prefix_match = "${var.container_name}/${trim(var.processed_prefix, "/")}/"
}

resource "random_string" "storage_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true

  # Keep the suffix stable across runs while the RG (and therefore the account
  # identity) stays the same; rotate it only if the owning RG is replaced.
  keepers = {
    rg_id = var.rg_id
  }
}

module "storage_account" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.6"

  name      = local.storage_account_name
  parent_id = var.rg_id
  location  = var.location
  tags      = var.tags

  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"

  min_tls_version                   = "TLS1_2"
  shared_access_key_enabled         = false
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  default_to_oauth_authentication   = true
  infrastructure_encryption_enabled = true

  # Public reachability stays open so portal/CLI can connect, but access is
  # gated by Entra ID (shared keys are disabled). Tighten with ip_rules or set
  # default_action = "Deny" once the trusted client IPs are known.
  network_rules = {
    default_action = "Allow"
    bypass         = ["AzureServices", "Logging", "Metrics"]
  }

  enable_telemetry = false
}

resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_id    = module.storage_account.resource_id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = module.storage_account.resource_id

  rule {
    name    = "expire-${replace(trim(var.processed_prefix, "/"), "/", "-")}"
    enabled = true

    filters {
      prefix_match = [local.processed_prefix_match]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = var.processed_retention_days
      }
    }
  }

  depends_on = [azurerm_storage_container.this]
}
