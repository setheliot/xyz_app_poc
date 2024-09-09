# Define the app name
locals {
  appname = "XYZDemoApp-${var.env_name}"
}

# This defines the kubernetes deployment for the demo app
resource "kubernetes_deployment" "xyz-demo-app" {
  metadata {
    name = "xyz-demo-app-${var.env_name}"
    labels = {
      App = local.appname
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = local.appname
      }
    }
    template {
      metadata {
        labels = {
          App = local.appname
        }
      }
      spec {
        container {
          image = var.app_image
          name  = "xyzdemoapp-container-${var.env_name}"

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
        }
      }
    }
  }
}

# Define a load balancer for our demo app.

resource "kubernetes_service" "xyz-demo-elb" {
  metadata {
    name = "xyz-demo-elb-prod"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    }    
  }
  spec {
    selector = {
      App = kubernetes_deployment.xyz-demo-app.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}

output "lb_ip" {
  description = "Load Balancer Endpoint"
  value = kubernetes_service.xyz-demo-elb.status.0.load_balancer.0.ingress.0.hostname
}