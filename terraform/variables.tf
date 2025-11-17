# This file contains the variable definitions for the Terraform configuration of the Time API Azure Kubernetes Service (AKS) cluster.

variable "region" {
  description = "The location/region of the resource group"
  type        = string
  default     = "eastus"
}

variable "my_user_object_id" {
  description = "The object id of the user"
  type        = string
}

variable "github_runner_token" {
  description = "GitHub Actions runner registration token"
  type        = string
  sensitive   = true
}
