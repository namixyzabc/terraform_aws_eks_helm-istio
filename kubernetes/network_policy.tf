# network_policy.tf
resource "kubernetes_network_policy" "default_deny_ingress" {
  metadata {
    name      = "default-deny-ingress"
    namespace = "default" # Network Policy を適用する Namespace
  }
  spec {
    pod_selector {} # 全ての Pod に適用
    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "default_deny_egress" {
  metadata {
    name      = "default-deny-egress"
    namespace = "default" # Network Policy を適用する Namespace
  }
  spec {
    pod_selector {} # 全ての Pod に適用
    policy_types = ["Egress"]
  }
}
