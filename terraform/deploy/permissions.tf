# This file contains the configuration for a group creation, and permissions and role assignments for the Time API Azure Kubernetes Service (AKS) cluster.

resource "azuread_group" "kronos_admins" {
  display_name     = "kronos_admins"
  owners           = [var.my_user_object_id]
  security_enabled = true

  members = [
    var.my_user_object_id,
    data.azuread_client_config.current.object_id
  ]
}

resource "azurerm_role_assignment" "cluster_rg_access" {
  scope                = azurerm_resource_group.kronos_rg.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.kronos_cluster.identity[0].principal_id

  depends_on = [azurerm_kubernetes_cluster.kronos_cluster]
}

resource "azurerm_role_assignment" "kronos_admins_rg_access" {
  scope                = azurerm_resource_group.kronos_rg.id
  role_definition_name = "Contributor"
  principal_id         = azuread_group.kronos_admins.object_id

  depends_on = [azurerm_resource_group.kronos_rg]
}
