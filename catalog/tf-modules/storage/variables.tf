variable "location" {
  type        = string
  description = "Azure region where the storage account will be deployed."
}

variable "environment" {
  type        = string
  description = "Environment short name (e.g. dev, pre, pro). Used to compose the storage account name."

  validation {
    condition     = can(regex("^[a-z0-9]{2,6}$", var.environment))
    error_message = "environment must be 2-6 lowercase alphanumeric characters."
  }
}

variable "rg_id" {
  type        = string
  description = "Resource ID of the resource group that owns the storage account. Format: /subscriptions/{sub}/resourceGroups/{rg}."

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.rg_id))
    error_message = "rg_id must be a full Azure resource group resource ID."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to the storage account."
  default     = {}
}

variable "container_name" {
  type        = string
  description = "Name of the private blob container to create."
  default     = "images"

  validation {
    condition     = can(regex("^[a-z0-9](?:[a-z0-9]|-(?!-)){1,61}[a-z0-9]$", var.container_name))
    error_message = "container_name must be 3-63 chars, lowercase, alphanumeric or single hyphens, starting/ending with a letter or digit."
  }
}

variable "processed_prefix" {
  type        = string
  description = "Virtual folder (blob name prefix) under the container that the lifecycle rule targets."
  default     = "processed/"
}

variable "processed_retention_days" {
  type        = number
  description = "Number of days after last modification before a blob under processed_prefix is deleted."
  default     = 30

  validation {
    condition     = var.processed_retention_days >= 1 && var.processed_retention_days <= 36500
    error_message = "processed_retention_days must be between 1 and 36500."
  }
}
