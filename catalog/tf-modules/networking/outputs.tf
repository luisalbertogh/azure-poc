output "resource_group_id" {
  description = "The full Azure resource ID of the resource group created by this module."
  value       = module.resource_group.resource_id
}

output "resource_group_name" {
  description = "Name of the resource group created by this module."
  value       = module.resource_group.name
}

output "resource_group_location" {
  description = "Location of the resource group created by this module."
  value       = module.resource_group.location
}

output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = module.virtual_network.resource_id
}

output "vnet_name" {
  description = "Name of the virtual network."
  value       = module.virtual_network.name
}

output "functions_subnet_id" {
  description = "Resource ID of the Flex Consumption functions subnet (delegated to Microsoft.App/environments)."
  value       = azurerm_subnet.functions.id
}

output "private_endpoints_subnet_id" {
  description = "Resource ID of the private endpoints subnet."
  value       = azurerm_subnet.private_endpoints.id
}
