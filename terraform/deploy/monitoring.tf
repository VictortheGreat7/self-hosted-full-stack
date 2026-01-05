# This file contains the monitoring and logging configuration for the Time API application deployed on Azure Kubernetes Service (AKS).

resource "azurerm_log_analytics_workspace" "kronos_law" {
  name                = "${azurerm_resource_group.kronos_rg.name}-law"
  location            = azurerm_resource_group.kronos_rg.location
  resource_group_name = azurerm_resource_group.kronos_rg.name
}

resource "azurerm_monitor_diagnostic_setting" "kronos_audit_logs" {
  name                       = "${azurerm_resource_group.kronos_rg.name}-audit-logs"
  target_resource_id         = azurerm_kubernetes_cluster.kronos_cluster.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.kronos_law.id

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

  enabled_log {
    category = "cluster-autoscaler"
  }

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "guard"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
  depends_on = [azurerm_kubernetes_cluster.kronos_cluster]
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  create_namespace = false
  version          = "80.9.2"

  set = [
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
      value = "default"
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
      value = "10Gi"
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
      value = "default"
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
      value = "5Gi"
    },
    {
      name  = "grafana.persistence.storageClassName"
      value = "default"
    },
    {
      name  = "grafana.persistence.size"
      value = "5Gi"
    },
    {
      name  = "grafana.adminPassword"
      value = "admin"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    module.nginx-controller,
    azurerm_kubernetes_cluster.kronos_cluster
  ]
}