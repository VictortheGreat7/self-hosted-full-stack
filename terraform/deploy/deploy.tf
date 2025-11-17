# This script defines the instructions for the deployment of the world clock application to the Azure Kubernetes Service (AKS) cluster.

# Backend API Deployment
resource "kubernetes_deployment_v1" "backend" {
  metadata {
    name      = "world-clock-backend"
    namespace = "time-api"
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "world-clock-backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "world-clock-backend"
        }
      }

      spec {
        container {
          name  = "backend"
          image = "victorthegreat7/world-clock-backend:latest"

          port {
            container_port = 5000
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [module.nginx-controller, kubernetes_namespace_v1.time_api]
}

# Frontend Deployment
resource "kubernetes_deployment_v1" "frontend" {
  metadata {
    name      = "world-clock-frontend"
    namespace = "time-api"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "world-clock-frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "world-clock-frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = "victorthegreat7/world-clock-frontend:latest"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [module.nginx-controller, kubernetes_namespace_v1.time_api]
}

# Backend Service
resource "kubernetes_service_v1" "backend" {
  metadata {
    name      = "world-clock-backend-service"
    namespace = "time-api"
  }

  spec {
    selector = {
      app = "world-clock-backend"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 5000
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.backend]
}

# Frontend Service
resource "kubernetes_service_v1" "frontend" {
  metadata {
    name      = "world-clock-frontend-service"
    namespace = "time-api"
  }

  spec {
    selector = {
      app = "world-clock-frontend"
    }

    port {
      protocol    = "TCP"
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment_v1.frontend]
}

# Backend Load Test
resource "kubernetes_job_v1" "backend_loadtest" {
  metadata {
    name      = "backend-loadtest"
    namespace = "time-api"
  }

  spec {
    template {
      metadata {
        name = "backend-loadtest"
      }
      spec {
        container {
          name    = "loadtest"
          image   = "busybox"
          command = ["/bin/sh", "-c"]
          args = [<<-EOF
            echo "Testing backend API endpoints..."
            for i in $(seq 1 30); do 
              wget -q -O- http://world-clock-backend-service.time-api.svc.cluster.local:80/api/world-clocks && 
              echo "Backend request $i successful"; 
              sleep 0.1; 
            done
            echo "All backend tests completed successfully!"
          EOF
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit           = 4
    active_deadline_seconds = 300
  }

  depends_on = [kubernetes_service_v1.backend]
}

# Frontend Load Test
resource "kubernetes_job_v1" "frontend_loadtest" {
  metadata {
    name      = "frontend-loadtest"
    namespace = "time-api"
  }

  spec {
    template {
      metadata {
        name = "frontend-loadtest"
      }
      spec {
        container {
          name    = "loadtest"
          image   = "busybox"
          command = ["/bin/sh", "-c"]
          args = [<<-EOF
            echo "Testing frontend service..."
            for i in $(seq 1 30); do 
              wget -q -O- http://world-clock-frontend-service.time-api.svc.cluster.local:80/ && 
              echo "Frontend request $i successful"; 
              sleep 0.1; 
            done
            echo "All frontend tests completed successfully!"
          EOF
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit           = 4
    active_deadline_seconds = 300
  }

  depends_on = [kubernetes_service_v1.frontend]
}

resource "null_resource" "wait_for_ingress_webhook" {
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -e

      echo "Getting AKS credentials..."
      az aks get-credentials --resource-group "${azurerm_kubernetes_cluster.time_api_cluster.resource_group_name}" --name "${azurerm_kubernetes_cluster.time_api_cluster.name}" --overwrite-existing

      echo "Installing kubelogin..."
      sudo az aks install-cli

      echo "Converting kubeconfig with kubelogin..."
      kubelogin convert-kubeconfig -l azurecli

      echo "Waiting for ingress-nginx-controller DaemonSet pods to be ready..."
      for i in {1..100}; do
        READY=$(kubectl get daemonset ingress-nginx-controller -n kube-system -o jsonpath='{.status.numberReady}')
  
        echo "Attempt $i: $READY pods ready"

        if [[ "$READY" -ge 1 ]]; then
          echo "At least one DaemonSet pod is ready"
          break
        fi

        if [[ "$i" -eq 100 ]]; then
          echo "Timed out waiting for at least one DaemonSet pod to be ready"
          exit 1
        fi

        sleep 10
      done


      echo "Waiting for admission webhook to be ready..."
      for i in {1..100}; do
        echo "Checking webhook readiness... attempt $i"
        if kubectl get endpoints ingress-nginx-controller-admission -n kube-system -o jsonpath='{.subsets[*].addresses[*].ip}' | grep -q .; then
          echo "Webhook server is ready"
          exit 0
        fi
        sleep 10
      done

      echo "Timed out waiting for ingress-nginx admission webhook"
      exit 1
    EOT
  }

  depends_on = [module.nginx-controller]
}

resource "kubernetes_service_account_v1" "check_ingress_sa" {
  metadata {
    name      = "check-ingress-sa"
    namespace = "kube-system"
  }

  depends_on = [null_resource.wait_for_ingress_webhook]
}

resource "kubernetes_role_v1" "check_ingress_role" {
  metadata {
    name      = "check-ingress-role"
    namespace = "kube-system"
  }

  rule {
    api_groups = [""]
    resources  = ["endpoints"]
    verbs      = ["get", "list"]
  }

  depends_on = [kubernetes_service_account_v1.check_ingress_sa]
}

resource "kubernetes_role_binding_v1" "check_ingress_binding" {
  metadata {
    name      = "check-ingress-binding"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.check_ingress_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.check_ingress_sa.metadata[0].name
    namespace = "kube-system"
  }

  depends_on = [kubernetes_role_v1.check_ingress_role]
}

resource "kubernetes_job_v1" "wait_for_ingress_webhook" {
  metadata {
    name      = "check-ingress-webhook"
    namespace = "kube-system"
  }

  spec {
    template {
      metadata {
        name = "ingress-webhook-test"
      }
      spec {
        service_account_name = kubernetes_service_account_v1.check_ingress_sa.metadata[0].name
        container {
          name    = "check"
          image   = "bitnami/kubectl:latest"
          command = ["/bin/bash", "-c"]
          args = [
            <<-EOC
            kubectl auth can-i get endpoints -n kube-system
            for i in {1..100}; do
              echo "Checking for webhook admission endpoint..."
              IP=$(kubectl get endpoints ingress-nginx-controller-admission -n kube-system -o jsonpath='{.subsets[*].addresses[*].ip}')
              if [[ ! -z "$IP" ]]; then
                echo "Admission webhook is ready"
                exit 0
              fi
              echo "Attempt $i: Admission webhook not ready yet"
              sleep 10
            done
            echo "Timed out waiting for admission webhook"
            exit 1
            EOC
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit           = 4
    active_deadline_seconds = 1000
  }

  depends_on = [null_resource.wait_for_ingress_webhook]
}

# Ingress Configuration for routing traffic
resource "kubernetes_ingress_v1" "world_clock" {
  metadata {
    name      = "world-clock-ingress"
    namespace = "time-api"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
    }
  }

  spec {
    ingress_class_name = "nginx"

    rule {
      http {
        # Route /api/* to backend
        path {
          path      = "/api(/|$)(.*)"
          path_type = "ImplementationSpecific"
          backend {
            service {
              name = kubernetes_service_v1.backend.metadata[0].name
              port {
                number = kubernetes_service_v1.backend.spec[0].port[0].port
              }
            }
          }
        }

        # Route / to frontend
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service_v1.frontend.metadata[0].name
              port {
                number = kubernetes_service_v1.frontend.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service_v1.backend, kubernetes_service_v1.frontend, azurerm_dashboard_grafana.timeapi_grafana, null_resource.wait_for_ingress_webhook, kubernetes_job_v1.wait_for_ingress_webhook]
}
