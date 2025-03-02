# helm_charts.tf
data "aws_eks_cluster_auth_token" "token" {
  name = module.eks.cluster_name
}

data "kubernetes_service_account_token" "argo_cd" {
  cluster_ip_address = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token = data.aws_eks_cluster_auth_token.token.token

  name      = "argocd-server"
  namespace = "argo-cd"
}


resource "helm_release" "aws_load_balancer_controller" {
  name      = "aws-load-balancer-controller"
  chart     = "aws-load-balancer-controller"
  repository = "oci://public.ecr.aws/eks/aws-load-balancer-controller"
  version   = "v2.7.0" # 最新バージョンを確認
  namespace = "kube-system"

  set_values = [
    "clusterName=${module.eks.cluster_name}",
    "serviceAccount.create=false",
    "serviceAccount.name=aws-load-balancer-controller",
    "vpcId=${module.vpc.vpc_id}",
    "subnetIds=${join(",", module.vpc.public_subnet_ids)}",
  ]

  depends_on = [module.eks, module.iam]
}

resource "helm_release" "cluster_autoscaler" {
  name      = "cluster-autoscaler"
  chart     = "cluster-autoscaler"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  version   = "9.0.3" # 最新バージョンを確認
  namespace = "kube-system"

  set_values = [
    "cloudProvider=aws",
    "awsRegion=${var.aws_region}",
    "autoDiscovery.clusterName=${module.eks.cluster_name}",
    "rbac.create=true",
    "serviceAccount.create=true",
    "serviceAccount.name=cluster-autoscaler",
  ]

  depends_on = [module.eks, module.iam, aws_eks_node_group.workers]
}

resource "helm_release" "argo_cd" {
  name      = "argo-cd"
  chart     = "argo-cd"
  repository = "oci://registry-1.docker.io/argocd"
  version   = "5.5.5" # 最新バージョンを確認
  namespace = "argo-cd"
  create_namespace = true

  set_values = [
    "server.ingress.enabled=true",
    "server.ingress.ingressClassName=aws-load-balancer-controller",
    "server.ingress.hosts[0]=${var.subdomain_name}.${var.domain_name}",
    "server.ingress.tls[0].hosts[0]=${var.subdomain_name}.${var.domain_name}",
    "server.ingress.tls[0].secretName=argocd-server-tls",
    "server.serviceAccount.create=true",
    "server.serviceAccount.name=argocd-server",
    "server.admin.password=${var.argo_cd_admin_password}", # Secrets Manager連携を推奨
    "redis.enabled=true",
    "redis-ha.enabled=false", # Redis HA を有効にする場合は redis-ha.enabled=true に変更
    "postgresql.enabled=false", # PostgreSQL を利用する場合は postgresql.enabled=true に変更
  ]

  depends_on = [module.eks, module.vpc, helm_release.aws_load_balancer_controller, module.route53_acm]
}

resource "helm_release" "istio_base" {
  name      = "istio-base"
  chart     = "base"
  repository = "oci://registry-1.docker.io/istio/helm"
  version   = "1.19.3" # 最新バージョンを確認
  namespace = "istio-system"
  create_namespace = true
}

resource "helm_release" "istiod" {
  name      = "istiod"
  chart     = "istiod"
  repository = "oci://registry-1.docker.io/istio/helm"
  version   = "1.19.3" # istio_base と同じバージョン
  namespace = "istio-system"

  depends_on = [helm_release.istio_base]
}

resource "helm_release" "istio_gateway" {
  name      = "istio-ingressgateway"
  chart     = "gateway"
  repository = "oci://registry-1.docker.io/istio/helm"
  version   = "1.19.3" # istio_base, istiod と同じバージョン
  namespace = "istio-system"

  set_values = [
    "service.type=LoadBalancer",
    "service.annotations.\"service\\.beta\\.kubernetes\\.io/aws-load-balancer-type\"=nlb",
    "service.annotations.\"service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme\"=internet-facing",
  ]


  depends_on = [helm_release.istiod]
}

resource "helm_release" "metrics_server" {
  name      = "metrics-server"
  chart     = "metrics-server"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  version   = "8.4.0" # 最新バージョンを確認
  namespace = "kube-system"
  create_namespace = true

  depends_on = [module.eks]
}
