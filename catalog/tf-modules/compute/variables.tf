variable "location" {
  type        = string
  description = "Azure region where the compute resources will be deployed."
}

variable "environment" {
  type        = string
  description = "Environment short name (e.g. dev, pre, pro). Used in resource naming."

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.environment))
    error_message = "environment must be 2-6 lowercase alphanumeric characters."
  }
}

variable "rg_id" {
  type        = string
  description = "Resource ID of the resource group that owns these resources."

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.rg_id))
    error_message = "rg_id must be a full Azure resource group resource ID."
  }
}

variable "rg_name" {
  type        = string
  description = "Name of the resource group that owns these resources."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every resource in this module."
  default     = {}
}

# ==============================================================================
# Networking – provided by the networking unit dependency
# ==============================================================================
variable "vnet_id" {
  type        = string
  description = "Resource ID of the virtual network. Used to link private DNS zones."
}

variable "functions_subnet_id" {
  type        = string
  description = <<-EOT
    Resource ID of the subnet delegated to Microsoft.App/environments.
    Used for Flex Consumption VNet integration (outbound traffic).
    The subnet name must not contain underscore characters.
  EOT
}

variable "private_endpoints_subnet_id" {
  type        = string
  description = "Resource ID of the subnet used for private endpoints (inbound access)."
}

# ==============================================================================
# Images storage – provided by the storage unit dependency
# ==============================================================================
variable "images_storage_account_id" {
  type        = string
  description = "Resource ID of the images storage account. The function identity will receive Storage Blob Data Contributor on this scope."
}

variable "images_storage_account_name" {
  type        = string
  description = "Name of the images storage account. Passed to the function as an app setting."
}

variable "images_container_name" {
  type        = string
  description = "Name of the images blob container. Passed to the function as an app setting."
  default     = "images"
}

# ==============================================================================
# Cosmos DB – optional, resolved when the Cosmos DB unit is provisioned
# ==============================================================================
variable "cosmos_db_account_id" {
  type        = string
  description = <<-EOT
    Resource ID of the Cosmos DB account. When provided, the function identity
    is granted the built-in \"Cosmos DB Built-in Data Contributor\" SQL role.
    Leave empty until the Cosmos DB resource is created.
  EOT
  default     = ""
}

variable "cosmos_db_account_uri" {
  type        = string
  description = "Cosmos DB account URI (HTTPS endpoint). Passed to the function as COSMOS_DB_ACCOUNT_URI app setting."
  default     = ""
}

# ==============================================================================
# Azure AI Foundry / Content Understanding – optional
# ==============================================================================
variable "foundry_account_id" {
  type        = string
  description = <<-EOT
    Resource ID of the Azure AI Foundry (Cognitive Services) account hosting
    Content Understanding. When provided, the function identity is granted
    \"Cognitive Services User\" on this scope.
    Leave empty until the AI Foundry resource is created.
  EOT
  default     = ""
}

variable "foundry_content_understanding_endpoint" {
  type        = string
  description = "Azure AI Foundry Content Understanding endpoint URL. Passed to the function as CONTENT_UNDERSTANDING_ENDPOINT app setting."
  default     = ""
}

# ==============================================================================
# Function App scaling
# ==============================================================================
variable "maximum_instance_count" {
  type        = number
  description = "Maximum number of instances the function app can scale out to. Supported values: 1-1000."
  default     = 100

  validation {
    condition     = var.maximum_instance_count >= 1 && var.maximum_instance_count <= 1000
    error_message = "maximum_instance_count must be between 1 and 1000."
  }
}

variable "instance_memory_in_mb" {
  type        = number
  description = "Memory size in MB for each function app instance. Supported values: 512, 2048, 4096."
  default     = 2048

  validation {
    condition     = contains([512, 2048, 4096], var.instance_memory_in_mb)
    error_message = "instance_memory_in_mb must be one of: 512, 2048, 4096."
  }
}

# ==============================================================================
# Event Hub – optional, resolved when the eventhub unit is provisioned
# ==============================================================================
variable "event_hub_namespace_fqdn" {
  type        = string
  description = <<-EOT
    Fully qualified domain name of the Event Hubs Namespace
    (e.g. evhns-poc-dev.servicebus.windows.net). Set as the
    EventHubConnection__fullyQualifiedNamespace app setting so the function
    runtime connects via managed identity (no SAS connection strings).
    Leave empty until the eventhub unit is provisioned.
  EOT
  default     = ""
}

variable "event_hub_name" {
  type        = string
  description = "Name of the Event Hub. Passed to the function as the EVENT_HUB_NAME app setting."
  default     = ""
}

variable "event_hub_consumer_group" {
  type        = string
  description = "Name of the dedicated Event Hub consumer group for this function. Passed as EVENT_HUB_CONSUMER_GROUP."
  default     = "$Default"
}

variable "event_hub_id" {
  type        = string
  description = <<-EOT
    Resource ID of the Event Hub. When provided, the function identity is
    granted the built-in \"Azure Event Hubs Data Receiver\" role scoped to
    this specific hub (principle of least privilege).
    Leave empty until the eventhub unit is provisioned.
  EOT
  default     = ""
}
