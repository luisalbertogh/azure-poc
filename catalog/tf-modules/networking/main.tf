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

# ==============================================================================
# Virtual Network – private-only networking backbone
# All workloads in this POC run inside this VNet. No public ingress is allowed
# beyond what is explicitly enabled through Private Endpoints.
# ==============================================================================
module "virtual_network" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.7"

  name                = "vnet-poc-${var.environment}"
  location            = var.location
  resource_group_name = module.resource_group.name
  address_space       = [var.vnet_address_space]
  tags                = var.tags

  enable_telemetry = false

  depends_on = [module.resource_group]
}

# ==============================================================================
# Subnet – Flex Consumption VNet integration (outbound traffic)
# ------------------------------------------------------------------------------
# IMPORTANT constraints for Flex Consumption plan:
#   - Delegation MUST be to "Microsoft.App/environments" (not Microsoft.Web/serverFarms)
#   - Subnet name MUST NOT contain underscore (_) characters (Flex Consumption limitation)
#   - Minimum /27 (27 usable IPs); /26 recommended for scale or multiple apps
#   - The Microsoft.App resource provider MUST be registered in the subscription
# ==============================================================================
resource "azurerm_subnet" "functions" {
  name                 = "snet-functions"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [var.functions_subnet_prefix]

  delegation {
    name = "delegation"
    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }

  depends_on = [module.virtual_network]
}

# ==============================================================================
# Subnet – Private Endpoints
# Hosts private endpoints for Function App, Storage, Cosmos DB, and AI Foundry.
# No service delegation is required on this subnet.
# ==============================================================================
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe"
  resource_group_name  = module.resource_group.name
  virtual_network_name = module.virtual_network.name
  address_prefixes     = [var.private_endpoints_subnet_prefix]

  depends_on = [module.virtual_network]
}
