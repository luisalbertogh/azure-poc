output "function_app_id" {
  description = "Resource ID of the Azure Function App."
  value       = azurerm_function_app_flex_consumption.main.id
}

output "function_app_name" {
  description = "Name of the Azure Function App."
  value       = azurerm_function_app_flex_consumption.main.name
}

output "function_app_principal_id" {
  description = "Principal ID of the Function App system-assigned managed identity."
  value       = azurerm_function_app_flex_consumption.main.identity[0].principal_id
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App (accessible only via private endpoint)."
  value       = azurerm_function_app_flex_consumption.main.default_hostname
}

output "fn_storage_account_id" {
  description = "Resource ID of the Function App's dedicated storage account."
  value       = module.fn_storage_account.resource_id
}

output "fn_storage_account_name" {
  description = "Name of the Function App's dedicated storage account."
  value       = module.fn_storage_account.name
}

output "application_insights_connection_string" {
  description = "Application Insights connection string for the Function App."
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "private_endpoint_id" {
  description = "Resource ID of the Function App private endpoint."
  value       = azurerm_private_endpoint.fn_app.id
}

output "private_endpoint_ip" {
  description = "Private IP address of the Function App private endpoint."
  value       = azurerm_private_endpoint.fn_app.private_service_connection[0].private_ip_address
}
