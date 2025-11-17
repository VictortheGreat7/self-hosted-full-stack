# This file contains the data sources that are used in the Terraform configuration.
data "azurerm_kubernetes_service_versions" "current" {
  location        = var.region
  include_preview = false
}

data "azuread_client_config" "current" {}

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_cluster" "time_api_cluster" {
  name                = azurerm_kubernetes_cluster.time_api_cluster.name
  resource_group_name = azurerm_kubernetes_cluster.time_api_cluster.resource_group_name

  depends_on = [
    azurerm_kubernetes_cluster.time_api_cluster
  ]
}

data "kubernetes_service" "nginx_ingress" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "kube-system"
  }
  depends_on = [module.nginx-controller]
}
