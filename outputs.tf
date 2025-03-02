# outputs.tf
output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKSクラスタ名"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "EKSクラスタエンドポイント"
}

output "kubeconfig" {
  value       = module.eks.kubeconfig
  description = "kubeconfigファイルの内容"
  sensitive   = true
}

output "argo_cd_admin_password" {
  value       = var.argo_cd_admin_password # Secrets Manager連携後は Secrets Manager から取得するように変更
  description = "Argo CD admin パスワード (初期値)"
  sensitive   = true
}

output "grafana_endpoint" {
  value       = kubernetes_service.grafana_service.status.0.load_balancer.0.ingress.0.hostname
  description = "Grafana エンドポイント"
}

output "cloudfront_domain_name" {
  value       = module.cloudfront_waf.cloudfront_domain_name
  description = "CloudFront ドメイン名"
}
