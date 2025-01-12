resource "kubernetes_service" "xyz-demo-elb" {
  metadata {
    name = "xyz-demo-elb-${var.env_name}"
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type"                     = "nlb"
      "service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags" = "Terraform=true,Environment=${var.env_name},app=${var.app_name}"
    }
  }
  spec {
    selector = {
      app = var.app_name
    }
    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }
}

