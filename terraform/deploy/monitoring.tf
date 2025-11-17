# This file contains the monitoring and logging configuration for the Time API application deployed on Azure Kubernetes Service (AKS).

resource "azurerm_log_analytics_workspace" "timeapi_law" {
  name                = "${azurerm_resource_group.time_api_rg.name}-law"
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name
}

resource "azurerm_monitor_workspace" "monitor_workspace" {
  name                = "timeapi-prometheus-monitor-workspace"
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name
}

resource "azurerm_monitor_data_collection_endpoint" "time_api_dce" {
  name                = "time-api-dce"
  resource_group_name = azurerm_resource_group.time_api_rg.name
  location            = azurerm_resource_group.time_api_rg.location
  kind                = "Linux"
}

resource "azurerm_monitor_data_collection_rule" "time_api_dcr" {
  name                        = "time-api-prometheus-dcr"
  resource_group_name         = azurerm_resource_group.time_api_rg.name
  location                    = azurerm_resource_group.time_api_rg.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.time_api_dce.id

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.monitor_workspace.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }

  data_sources {
    prometheus_forwarder {
      streams = ["Microsoft-PrometheusMetrics"]
      name    = "PrometheusDataSource"
    }
  }

  description = "Data collection rule for Prometheus metrics"
}

resource "azurerm_monitor_data_collection_rule_association" "time_api_dcra" {
  name                    = "time-api-dcra"
  target_resource_id      = azurerm_kubernetes_cluster.time_api_cluster.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.time_api_dcr.id
  description             = "Association between AKS cluster and Prometheus DCR"
}

resource "azurerm_monitor_diagnostic_setting" "timeapi_audit_logs" {
  name                       = "${azurerm_resource_group.time_api_rg.name}-audit-logs"
  target_resource_id         = azurerm_kubernetes_cluster.time_api_cluster.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.timeapi_law.id

  enabled_log {
    category = "kube-apiserver"
  }

  enabled_log {
    category = "kube-controller-manager"
  }

  enabled_log {
    category = "kube-scheduler"
  }

  enabled_log {
    category = "kube-audit-admin"
  }

  enabled_log {
    category = "kube-audit"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "azurerm_dashboard_grafana" "timeapi_grafana" {
  name                = "timeapi-grafana"
  location            = azurerm_resource_group.time_api_rg.location
  resource_group_name = azurerm_resource_group.time_api_rg.name

  grafana_major_version             = 11
  api_key_enabled                   = true
  deterministic_outbound_ip_enabled = true
  public_network_access_enabled     = true

  identity {
    type = "SystemAssigned"
  }
  sku = "Standard"

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.monitor_workspace.id
  }

  depends_on = [module.nginx-controller]
}
