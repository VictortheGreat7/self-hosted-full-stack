# This file contains the Kubernetes Network Policies for the time-api namespace.

resource "kubernetes_network_policy_v1" "default_deny" {
  metadata {
    name      = "default-deny-all"
    namespace = "time-api"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "time-api"
      }
    }

    policy_types = ["Ingress", "Egress"]
   }

  depends_on = [azurerm_kubernetes_cluster.time_api_cluster]
}

resource "kubernetes_network_policy_v1" "allow_dns" {
  metadata {
    name      = "allow-dns-access"
    namespace = "time-api"
  }

  spec {
    pod_selector {
      match_labels = {
        app = "time-api"
      }
    }

    policy_types = ["Ingress", "Egress"]

    ingress {
      ports {
        protocol = "UDP"
        port     = 53
      }
      ports {
        protocol = "TCP"
        port     = 53
      }
    }

    egress {
      ports {
        protocol = "UDP"
        port     = 53
      }
      ports {
        protocol = "TCP"
        port     = 53
      }
    }
  }

  depends_on = [kubernetes_network_policy_v1.default_deny]
}

resource "kubernetes_network_policy_v1" "allow_ingress_to_time_api" {
  metadata {
    name      = "allow-ingress-to-time-api"
    namespace = "time-api"
  }

  spec {
    # Selects the time-api pods to which this policy applies
    pod_selector {
      match_labels = {
        app = "time-api"
      }
    }

    policy_types = ["Ingress"]

    # Defines the allowed incoming traffic
    ingress {
      # Allow traffic from specific pods
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "kube-system"
          }
        }
        pod_selector {
          match_labels = {
            "app.kubernetes.io/name" = "ingress-nginx"
          }
        }
      }
      from {
        namespace_selector {
          match_labels = {
            "kubernetes.io/metadata.name" = "time-api"
          }
        }
        # Select pods created by the time-api-loadtest job.
        # Job pods typically get a 'job-name' label derived from the job's metadata.name.
        pod_selector {
          match_labels = {
            "job-name" = "time-api-loadtest"
            "job-name" = "backend-loadtest"
            "job-name" = "frontend-loadtest"
          }
        }
      }
      # Allow traffic on specific ports
      ports {
        protocol = "TCP"
        port     = 5000 # The container_port of your time-api deployment
      }
      ports {
        protocol = "TCP"
        port     = 80
      }
    }
  }

  depends_on = [kubernetes_network_policy_v1.default_deny]
}
