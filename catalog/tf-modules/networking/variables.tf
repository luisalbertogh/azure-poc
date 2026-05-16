variable "location" {
  type        = string
  description = "Azure region where all resources will be deployed."
  default     = "spaincentral"
}

variable "environment" {
  type        = string
  description = "Environment short name (e.g. dev, pre, pro). Used in resource naming."
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged with the baseline tags and applied to every resource."
  default     = {}
}

variable "rg_name" {
  type        = string
  description = "Resource group name."
}

variable "vnet_address_space" {
  type        = string
  description = "CIDR address space for the virtual network (e.g. '10.10.0.0/16')."
  default     = "10.10.0.0/16"
}

variable "functions_subnet_prefix" {
  type        = string
  description = <<-EOT
    CIDR prefix for the Flex Consumption functions subnet.
    Minimum /27 (27 usable IPs); /26 is recommended for multiple apps or high-scale
    workloads. Name must not contain underscore characters (Flex Consumption limitation).
    The subnet is delegated to Microsoft.App/environments.
  EOT
  default     = "10.10.1.0/26"
}

variable "private_endpoints_subnet_prefix" {
  type        = string
  description = "CIDR prefix for the private endpoints subnet."
  default     = "10.10.2.0/27"
}
