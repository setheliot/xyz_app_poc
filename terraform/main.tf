# Define the app name
locals {
  appname = "XYZDemoApp-${var.env_name}"
}

# This defines the kubernetes deployment for the XYZ app
resource "kubernetes_deployment" "xyz_deployment_app" {
  metadata {
    name = "xyz-deployment-app-${var.env_name}"
    labels = {
      app = local.appname
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = local.appname
      }
    }
    template {
      metadata {
        labels = {
          app = local.appname
        }
      }
      spec {
        container {
          image = var.app_image
          name  = "xyz-container-app-${var.env_name}"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
          # Add environment variable using Kubernetes Downward API to get node name
          env {
            name = "NODE_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }
          # Add environment variable for the region
          env {
            name  = "AWS_REGION"
            value = local.region # This is the region where the EKS cluster is deployed
          }
        } #container
      }
    }
  }
}

# Kubernetes Ingress Resource for ALB via AWS Load Balancer Controller
resource "kubernetes_ingress_v1" "xyz_ingress_alb" {
  metadata {
    name      = "xyz-ingress-alb-${var.env_name}"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"
      # "alb.ingress.kubernetes.io/subnets"                  = var.public_subnets
      "alb.ingress.kubernetes.io/tags" = "Terraform=true,Environment=${var.env_name}"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.xyz_service_alb.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}

# Kubernetes Service for the App
resource "kubernetes_service_v1" "xyz_service_alb" {
  metadata {
    name      = "xyz-service-alb-${var.env_name}"
    namespace = "default"
    labels = {
      app = local.appname
    }
  }

  spec {
    selector = {
      app = local.appname
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS Name"
  value = (
    length(kubernetes_ingress_v1.xyz_ingress_alb.status) > 0 &&
    length(kubernetes_ingress_v1.xyz_ingress_alb.status[0].load_balancer) > 0 &&
    length(kubernetes_ingress_v1.xyz_ingress_alb.status[0].load_balancer[0].ingress) > 0
  ) ? kubernetes_ingress_v1.xyz_ingress_alb.status[0].load_balancer[0].ingress[0].hostname : "ALB is still provisioning"
}

