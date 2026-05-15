output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = module.storage_account.resource_id
}

output "storage_account_name" {
  description = "Name of the storage account."
  value       = module.storage_account.name
}

output "container_id" {
  description = "Resource ID of the private blob container."
  value       = azurerm_storage_container.this.id
}

output "container_name" {
  description = "Name of the private blob container."
  value       = azurerm_storage_container.this.name
}

output "blob_endpoint" {
  description = "Primary blob endpoint of the storage account."
  value       = module.storage_account.fqdn
}
