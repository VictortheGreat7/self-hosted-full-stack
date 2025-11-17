resource "azurerm_kubernetes_cluster" "time_api_cluster" {
  name                = "aks-${azurerm_resource_group.time_api_rg.name}-cluster"
  resource_group_name = azurerm_resource_group.time_api_rg.name
  location            = azurerm_resource_group.time_api_rg.location
  dns_prefix          = "dns-${azurerm_resource_group.time_api_rg.name}-cluster"
  kubernetes_version  = data.azurerm_kubernetes_service_versions.current.default_version
  node_resource_group = "nrg-aks-${azurerm_resource_group.time_api_rg.name}-cluster"

  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false

  default_node_pool {
    name                 = "default"
    vm_size              = "Standard_D2_v2"
    auto_scaling_enabled = true
    max_count            = 2
    min_count            = 1
    os_disk_size_gb      = 30
    type                 = "VirtualMachineScaleSets"
    vnet_subnet_id       = azurerm_subnet.time_api_subnet.id
    node_labels = {
      "nodepool-type" = "system"
      "environment"   = "test"
      "nodepoolos"    = "linux"
    }
    tags = {
      "nodepool-type" = "system"
      "environment"   = "test"
      "nodepoolos"    = "linux"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = [azuread_group.time_api_admins.object_id]
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    load_balancer_sku = "standard"
    dns_service_ip    = "172.16.0.10"
    service_cidr      = "172.16.0.0/16"
    outbound_type     = "userAssignedNATGateway"
    nat_gateway_profile {
      idle_timeout_in_minutes = 4
    }
  }

  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.timeapi_law.id
    msi_auth_for_monitoring_enabled = true
  }

  monitor_metrics {
    annotations_allowed = null
    labels_allowed      = null
  }

  cost_analysis_enabled = true
  sku_tier              = "Standard"

  depends_on = [azuread_group.time_api_admins, azurerm_subnet_nat_gateway_association.time_api_natgw_subnet_association, azurerm_nat_gateway_public_ip_association.time_api_natgw_public_ip_association]

  tags = {
    Environment = "test"
  }
}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].cluster_ca_certificate)
  }
}

provider "kubectl" {
  host                   = azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config[0].cluster_ca_certificate)
}

resource "kubernetes_namespace_v1" "time_api" {
  metadata {
    name = "time-api"
  }

  depends_on = [azurerm_kubernetes_cluster.time_api_cluster]
}

resource "kubernetes_config_map_v1" "time_api_config" {
  metadata {
    name      = "time-api-config"
    namespace = "time-api"
  }

  data = {
    TIME_ZONE = "UTC"
  }

  depends_on = [kubernetes_namespace_v1.time_api, azurerm_kubernetes_cluster.time_api_cluster]
}

module "nginx-controller" {
  source  = "terraform-iaac/nginx-controller/helm"
  version = ">=2.3.0"

  timeout = 900

  depends_on = [azurerm_kubernetes_cluster.time_api_cluster]
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.time_api_cluster.name
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.time_api_cluster.kube_admin_config
  sensitive = true
}

output "ingress_ip" {
  value = data.kubernetes_service.nginx_ingress.status.0.load_balancer.0.ingress.0.ip
}
