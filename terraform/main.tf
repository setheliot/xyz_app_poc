# Define the app name
locals {
  app_name = "XYZDemoApp-${var.env_name}"
}

# This defines the kubernetes deployment for the XYZ app
resource "kubernetes_deployment" "xyz_deployment_app" {
  metadata {
    name = "xyz-deployment-app-${var.env_name}"
    labels = {
      app = local.app_name
    }
  }

  spec {
    replicas = 3
    selector {
      match_labels = {
        app = local.app_name
      }
    }
    template {
      metadata {
        labels = {
          app = local.app_name
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

          # Mount the PVC as a volume in the container
          volume_mount {
            name       = "ebs-k8s-attached-storage"
            mount_path = "/app/data" # Path inside the container
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

        # Define the volume using the PVC
        volume {
          name = "ebs-k8s-attached-storage"

          persistent_volume_claim {
            claim_name = "ebs-volume-claim" #TODO: fix hardcoded name
          }
        } #volume
      }   #spec
    }     #template
  }
}

# Create ALB 
# This is the usual path followed - use_lbc will usually be true
module "lbc-alb" {
  source   = "./modules/lbc-alb"
  env_name = var.env_name
  app_name = local.app_name
  count    = var.use_lbc ? 1 : 0
}

output "alb_dns_name" {
  value = var.use_lbc ? module.lbc-alb[0].alb_dns_name : "(ALB not provisioned)"
}


###############
# Create NLB
# This is the unuusual path
# Uses the legacy Kubernetes service controller. Used for legacy testing
module "legacy-nlb" {
  source   = "./modules/legacy-nlb"
  env_name = var.env_name
  app_name = local.app_name
  count    = var.use_lbc ? 0 : 1
}

output "nlb_dns_name" {
  value = var.use_lbc ? "(This app uses an ALB)" : module.legacy-nlb[0].nlb_dns_name
}

