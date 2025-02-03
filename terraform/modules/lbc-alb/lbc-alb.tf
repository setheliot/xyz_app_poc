
# Note, do set "kubernetes.io/ingress.class" = "alb" in Ingress.  That is deprecated.
# https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.2/guide/ingress/ingress_class/#deprecated-kubernetesioingressclass-annotation
# Instead specify an IngressClass to use.

# This is the IngressClass created when Helm installed the AWS LBC
locals {
    ingress_class_name = "alb"
}

# Kubernetes Ingress Resource for ALB via AWS Load Balancer Controller
resource "kubernetes_ingress_v1" "xyz_ingress_alb" {
  metadata {
    name      = "xyz-ingress-alb-${var.env_name}"
    namespace = "default"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60"
      "alb.ingress.kubernetes.io/tags"                     = "Terraform=true,Environment=${var.env_name}"
    }
  }

  spec {
    ingress_class_name = local.ingress_class_name

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
      app = var.app_name
    }
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}
