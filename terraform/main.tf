# Define the app name
locals {
  appname = "XYZDemoApp-${var.env_name}"
}

# This defines the kubernetes deployment for the XYZ app
resource "kubernetes_deployment" "xyz-demo-app" {
  metadata {
    name = "xyz-demo-app-${var.env_name}"
    labels = {
      App = local.appname
    }
  }

  spec {
    replicas = 3
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

# Define a load balancer (NLB) for our demo app.

resource "kubernetes_service" "xyz-demo-elb" {
  metadata {
    name = "xyz-demo-elb-${var.env_name}"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                     = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = "Terraform=true,Environment=${var.env_name}"
    }
  }
  spec {
    selector = {
      App = kubernetes_deployment.xyz-demo-app.spec.0.template.0.metadata[0].labels.App
    }
    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

output "lb_ip" {
  description = "Load Balancer Endpoint"
  value       = kubernetes_service.xyz-demo-elb.status.0.load_balancer.0.ingress.0.hostname
}
