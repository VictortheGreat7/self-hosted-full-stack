# # This file contains the monitoring and logging configuration for the Time API application deployed on Azure Kubernetes Service (AKS).

# resource "azurerm_log_analytics_workspace" "timeapi_law" {
#   name                = "${azurerm_resource_group.time_api_rg.name}-law"
#   location            = azurerm_resource_group.time_api_rg.location
#   resource_group_name = azurerm_resource_group.time_api_rg.name
# }

# resource "azurerm_monitor_workspace" "monitor_workspace" {
#   name                = "timeapi-prometheus-monitor-workspace"
#   location            = azurerm_resource_group.time_api_rg.location
#   resource_group_name = azurerm_resource_group.time_api_rg.name
# }

# resource "azurerm_monitor_data_collection_endpoint" "time_api_dce" {
#   name                = "time-api-dce"
#   resource_group_name = azurerm_resource_group.time_api_rg.name
#   location            = azurerm_resource_group.time_api_rg.location
#   kind                = "Linux"
# }

# resource "azurerm_monitor_data_collection_rule" "time_api_dcr" {
#   name                        = "time-api-prometheus-dcr"
#   resource_group_name         = azurerm_resource_group.time_api_rg.name
#   location                    = azurerm_resource_group.time_api_rg.location
#   data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.time_api_dce.id

#   destinations {
#     monitor_account {
#       monitor_account_id = azurerm_monitor_workspace.monitor_workspace.id
#       name               = "MonitoringAccount1"
#     }
#   }

#   data_flow {
#     streams      = ["Microsoft-PrometheusMetrics"]
#     destinations = ["MonitoringAccount1"]
#   }

#   data_sources {
#     prometheus_forwarder {
#       streams = ["Microsoft-PrometheusMetrics"]
#       name    = "PrometheusDataSource"
#     }
#   }

#   description = "Data collection rule for Prometheus metrics"
# }

# resource "azurerm_monitor_data_collection_rule_association" "time_api_dcra" {
#   name                    = "time-api-dcra"
#   target_resource_id      = azurerm_kubernetes_cluster.time_api_cluster.id
#   data_collection_rule_id = azurerm_monitor_data_collection_rule.time_api_dcr.id
#   description             = "Association between AKS cluster and Prometheus DCR"
# }

# resource "azurerm_monitor_diagnostic_setting" "timeapi_audit_logs" {
#   name                       = "${azurerm_resource_group.time_api_rg.name}-audit-logs"
#   target_resource_id         = azurerm_kubernetes_cluster.time_api_cluster.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.timeapi_law.id

#   enabled_log {
#     category = "kube-apiserver"
#   }

#   enabled_log {
#     category = "kube-controller-manager"
#   }

#   enabled_log {
#     category = "kube-scheduler"
#   }

#   enabled_log {
#     category = "kube-audit-admin"
#   }

#   enabled_log {
#     category = "kube-audit"
#   }

#   enabled_metric {
#     category = "AllMetrics"
#   }
# }

# resource "azurerm_dashboard_grafana" "timeapi_grafana" {
#   name                = "timeapi-grafana"
#   location            = azurerm_resource_group.time_api_rg.location
#   resource_group_name = azurerm_resource_group.time_api_rg.name

#   grafana_major_version             = 11
#   api_key_enabled                   = true
#   deterministic_outbound_ip_enabled = true
#   public_network_access_enabled     = true

#   identity {
#     type = "SystemAssigned"
#   }
#   sku = "Standard"

#   azure_monitor_workspace_integrations {
#     resource_id = azurerm_monitor_workspace.monitor_workspace.id
#   }

#   depends_on = [module.nginx-controller]
# }

# # Create Azure Disks for monitoring components
# resource "azurerm_managed_disk" "prometheus" {
#   name                = "prometheus-disk"
#   location            = azurerm_resource_group.time_api_rg.location
#   resource_group_name = azurerm_resource_group.time_api_rg.name
#   storage_account_type = "Standard_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = 50
# }

# resource "azurerm_managed_disk" "alertmanager" {
#   name                = "alertmanager-disk"
#   location            = azurerm_resource_group.time_api_rg.location
#   resource_group_name = azurerm_resource_group.time_api_rg.name
#   storage_account_type = "Standard_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = 10
# }

# resource "azurerm_managed_disk" "grafana" {
#   name                = "grafana-disk"
#   location            = azurerm_resource_group.time_api_rg.location
#   resource_group_name = azurerm_resource_group.time_api_rg.name
#   storage_account_type = "Standard_LRS"
#   create_option        = "Empty"
#   disk_size_gb         = 10
# }

# Create monitoring namespace
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [azurerm_kubernetes_cluster.time_api_cluster]
}

# Deploy kube-prometheus-stack with Azure storage class
resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  create_namespace = false
  version          = "80.9.2"

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = "default"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = "10Gi"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
    value = "default"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
    value = "5Gi"
  }

  set {
    name  = "grafana.persistence.storageClassName"
    value = "default"
  }

  set {
    name  = "grafana.persistence.size"
    value = "5Gi"
  }

  set {
    name  = "grafana.adminPassword"
    value = "admin"
  }

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    module.nginx-controller,
    azurerm_kubernetes_cluster.time_api_cluster
  ]
}

# Data source for nginx ingress
data "kubernetes_service_v1" "nginx_ingress" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "kube-system"
  }
  depends_on = [module.nginx-controller]
}