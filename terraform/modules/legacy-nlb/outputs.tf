output "nlb_dns_name" {
  description = "Legacy Network Load Balancer DNS Name"
  value       = kubernetes_service.xyz-demo-elb.status[0].load_balancer[0].ingress[0].hostname

}
