# This file contains the provider configurations for the Microsoft Azure Cloud Infrastructure for the Time API application.

terraform {
  required_providers {
    azuread = "3.4.0"
    azurerm = "4.34.0"
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.37.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "2.1.3"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = "d31507f4-324c-4bd1-abe1-5cdf45cba77d"
}
