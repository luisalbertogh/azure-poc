# ==============================================================================
# Resource Group
# ==============================================================================
module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.2"

  name     = var.rg_name
  location = var.location
  tags     = var.tags

  enable_telemetry = false
}
