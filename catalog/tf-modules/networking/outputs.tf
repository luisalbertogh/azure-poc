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
