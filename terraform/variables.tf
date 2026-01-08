# This file contains the variable definitions for the Terraform configuration of the Time API Azure Kubernetes Service (AKS) cluster.

variable "region" {
  description = "The location/region of the resource group"
  type        = string
  default     = "eastus"
}

variable "azure_subscription" {
  description = "The Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "my_user_object_id" {
  description = "The object id of the user"
  type        = string
  sensitive   = true
}

variable "github_runner_token" {
  description = "GitHub Actions runner registration token"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for managing DNS records"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
  sensitive   = true
}

variable "subdomains" {
  description = "List of subdomains to create"
  type        = list(string)
  default = [
    "kronos",
    "backend"
  ]
}

variable "domain" {
  description = "The root domain for the world clock application"
  type        = string
  default     = "mywonderworks.tech"
}
