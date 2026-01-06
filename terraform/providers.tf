# This file contains the provider configurations for the Microsoft Azure Cloud Infrastructure for the Time API application.

terraform {
  required_providers {
    azurerm = ">= 4.57.0"
    azuread = ">= 3.7.0"
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.1.1"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.1.3"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 5.15.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription
}
