variable "location" {
  type        = string
  description = "Azure region where the Event Hubs resources will be deployed."
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
# Storage account – provided by the storage unit dependency
# ==============================================================================
variable "storage_account_id" {
  type        = string
  description = "Resource ID of the images storage account. Used as the source for the Event Grid System Topic."
}

variable "images_container_name" {
  type        = string
  description = "Name of the images blob container. Used to filter Event Grid events by subject prefix."
  default     = "images"
}

# ==============================================================================
# Event Hubs Namespace configuration
# ==============================================================================
variable "event_hub_namespace_sku" {
  type        = string
  description = "SKU for the Event Hubs Namespace. Standard is required for managed-identity Event Grid delivery."
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.event_hub_namespace_sku)
    error_message = "event_hub_namespace_sku must be Standard or Premium (Basic does not support managed-identity delivery from Event Grid)."
  }
}

# ==============================================================================
# Event Hub configuration
# ==============================================================================
variable "event_hub_partition_count" {
  type        = number
  description = "Number of partitions for the Event Hub. Must be between 1 and 32."
  default     = 2

  validation {
    condition     = var.event_hub_partition_count >= 1 && var.event_hub_partition_count <= 32
    error_message = "event_hub_partition_count must be between 1 and 32."
  }
}

variable "event_hub_message_retention" {
  type        = number
  description = "Number of days to retain messages in the Event Hub (1-7 for Standard tier)."
  default     = 1

  validation {
    condition     = var.event_hub_message_retention >= 1 && var.event_hub_message_retention <= 7
    error_message = "event_hub_message_retention must be between 1 and 7 days."
  }
}
