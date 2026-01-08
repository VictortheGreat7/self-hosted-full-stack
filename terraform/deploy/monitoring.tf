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
      value = "5Gi"
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
      value = "default"
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
      value = "3Gi"
    },
    {
      name  = "grafana.persistence.storageClassName"
      value = "default"
    },
    {
      name  = "grafana.persistence.size"
      value = "3Gi"
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

resource "helm_release" "tempo" {
  name             = "tempo"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "tempo"
  namespace        = kubernetes_namespace_v1.monitoring.metadata[0].name
  create_namespace = false
  version          = "1.10.1"

  set = [
    {
      name  = "tempo.storage.trace.backend"
      value = "local"
    },
    {
      name  = "tempo.storage.trace.local.path"
      value = "/var/tempo/traces"
    },
    {
      name  = "tempo.receivers.otlp.protocols.grpc.endpoint"
      value = "0.0.0.0:4317"
    },
    {
      name  = "tempo.receivers.otlp.protocols.http.endpoint"
      value = "0.0.0.0:4318"
    },
    {
      name  = "persistence.enabled"
      value = "true"
    },
    {
      name  = "persistence.storageClassName"
      value = "default"
    },
    {
      name  = "persistence.size"
      value = "3Gi"
    }
  ]

  depends_on = [
    kubernetes_namespace_v1.monitoring,
    helm_release.kube_prometheus_stack
  ]
}

# Configure Grafana to use Tempo as a data source
resource "kubernetes_config_map_v1" "grafana_datasources" {
  metadata {
    name      = "grafana-tempo-datasource"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
    labels = {
      grafana_datasource = "1"
    }
  }

  data = {
    "tempo-datasource.yaml" = yamlencode({
      apiVersion = 1
      datasources = [
        {
          name      = "Tempo"
          type      = "tempo"
          access    = "proxy"
          url       = "http://tempo.monitoring:3100"
          isDefault = false
          jsonData = {
            tracesToLogsV2 = {
              datasourceUid = "prometheus"
            }
            tracesToMetrics = {
              datasourceUid = "prometheus"
            }
          }
        }
      ]
    })
  }

  depends_on = [helm_release.tempo]
}