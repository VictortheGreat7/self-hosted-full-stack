# This file contains the configuration for a group creation, and permissions and role assignments for the Time API Azure Kubernetes Service (AKS) cluster.

resource "azuread_group" "time_api_admins" {
  display_name     = "time_api_admins"
  owners           = [var.my_user_object_id]
  security_enabled = true

  members = [var.my_user_object_id, data.azuread_client_config.current.object_id]
}

resource "azurerm_role_assignment" "cluster_rg_access" {
  scope                = azurerm_resource_group.time_api_rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.time_api_cluster.identity[0].principal_id

  depends_on = [
    azurerm_kubernetes_cluster.time_api_cluster
  ]
}

resource "azurerm_role_assignment" "time_api_admins_rg_access" {
  scope                = azurerm_resource_group.time_api_rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.time_api_admins.object_id

  depends_on = [
    azurerm_resource_group.time_api_rg
  ]
}

resource "azurerm_role_assignment" "grafana_admin" {
  scope                = azurerm_dashboard_grafana.timeapi_grafana.id
  role_definition_name = "Grafana Admin"
  principal_id         = azuread_group.time_api_admins.object_id
}

resource "azurerm_role_assignment" "grafana_prometheus_reader" {
  scope                = azurerm_monitor_workspace.monitor_workspace.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.timeapi_grafana.identity[0].principal_id
}
