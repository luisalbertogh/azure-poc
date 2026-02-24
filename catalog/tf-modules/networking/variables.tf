variable "location" {
  type        = string
  description = "Azure region where all resources will be deployed."
  default     = "spaincentral"
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
