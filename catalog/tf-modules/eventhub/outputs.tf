output "eventhub_namespace_id" {
  description = "Resource ID of the Event Hubs Namespace."
  value       = azurerm_eventhub_namespace.main.id
}

output "eventhub_namespace_name" {
  description = "Name of the Event Hubs Namespace."
  value       = azurerm_eventhub_namespace.main.name
}

output "eventhub_namespace_fqdn" {
  description = "Fully qualified domain name of the Event Hubs Namespace. Used as the managed-identity connection endpoint in the function app (EventHubConnection__fullyQualifiedNamespace)."
  value       = "${azurerm_eventhub_namespace.main.name}.servicebus.windows.net"
}

output "eventhub_id" {
  description = "Resource ID of the Event Hub."
  value       = azurerm_eventhub.images.id
}

output "eventhub_name" {
  description = "Name of the Event Hub. Passed to the function app as the EVENT_HUB_NAME app setting."
  value       = azurerm_eventhub.images.name
}

output "eventhub_consumer_group_name" {
  description = "Name of the dedicated consumer group for the Azure Function. Passed to the function app as the EVENT_HUB_CONSUMER_GROUP app setting."
  value       = azurerm_eventhub_consumer_group.function.name
}

output "eventgrid_system_topic_name" {
  description = "Name of the Event Grid System Topic monitoring the storage account."
  value       = azurerm_eventgrid_system_topic.storage.name
}
