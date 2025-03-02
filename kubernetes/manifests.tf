# kubernetes_manifests.tf
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_manifest" "prometheus_configmap" {
  manifest = {
    apiVersion = "v1"
    kind = "ConfigMap"
    metadata = {
      name      = "prometheus-server-conf"
      namespace = kubernetes_namespace.monitoring.metadata.0.name
      labels = {
        name = "prometheus-server-conf"
      }
    }
    data = {
      "prometheus.yml" = yamlencode({
        global = {
          scrape_interval     = "30s"
          evaluation_interval = "30s"
        }
        scrape_configs = [
          {
            job_name = "kubernetes-apiservers"
            kubernetes_sd_configs = [{
              role = "apiservers"
            }]
            relabel_configs = [{
              action = "replace"
              source_labels = ["__meta_kubernetes_service_namespace", "__meta_kubernetes_service_name", "__meta_kubernetes_endpoint_port_name"]
              target_label  = "instance"
              regex       = "(.+);(.+);.+"
              replacement = "$1/$2"
            }]
          },
          {
            job_name = "kubernetes-nodes"
            kubernetes_sd_configs = [{
              role = "node"
            }]
            relabel_configs = [
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_node_label_(.+)"
              },
              {
                target_label = "instance"
                replacement = "$1"
                source_labels = ["__address__"]
              },
              {
                target_label = "node"
                source_labels = ["__address__"]
              }
            ]
          },
          {
            job_name = "kubernetes-pods"
            kubernetes_sd_configs = [{
              role = "pod"
            }]
            relabel_configs = [
              {
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_scrape"]
                action      = "keep"
                regex       = true
              },
              {
                source_labels = ["__meta_kubernetes_pod_annotation_prometheus_io_path"]
                action      = "replace"
                target_label  = "__metrics_path__"
                regex       = "(.+)"
              },
              {
                source_labels = ["__address__", "__meta_kubernetes_pod_annotation_prometheus_io_port"]
                action      = "replace"
                regex       = "([^:]+)(?::\\d+)?;(\\d+)"
                replacement = "$1:$2"
                target_label  = "__address__"
              },
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_pod_label_(.+)"
              },
              {
                source_labels = ["__meta_kubernetes_namespace"]
                action      = "replace"
                target_label  = "namespace"
              },
              {
                source_labels = ["__meta_kubernetes_pod_name"]
                action      = "replace"
                target_label  = "pod"
              }
            ]
          },
          {
            job_name = "kubernetes-cadvisor"
            kubernetes_sd_configs = [{
              role = "node"
            }]
            relabel_configs = [
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_node_label_(.+)"
              },
              {
                target_label = "instance"
                replacement = "$1"
                source_labels = ["__address__"]
              },
              {
                target_label = "node"
                source_labels = ["__address__"]
              }
            ]
          },
          {
            job_name = "kubernetes-service-endpoints"
            kubernetes_sd_configs = [{
              role = "endpoints"
            }]
            relabel_configs = [
              {
                action = "labelmap"
                regex  = "__meta_kubernetes_service_label_(.+)"
              },
              {
                source_labels = ["__meta_kubernetes_service_namespace"]
                action      = "replace"
                target_label  = "namespace"
              },
              {
                source_labels = ["__meta_kubernetes_service_name"]
                action      = "replace"
                target_label  = "service"
              }
            ]
          }
        ]
      })
    }
  }

  depends_on = [kubernetes_namespace.monitoring]
}


resource "kubernetes_deployment" "prometheus_deployment" {
  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
    labels = {
      app = "prometheus"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        containers {
          name  = "prometheus"
          image = "prom/prometheus:v2.47.0" # 最新バージョンを確認
          ports {
            container_port = 9090
          }
          volume_mounts {
            mount_path = "/etc/prometheus"
            name      = "config-volume"
          }
        }
        volumes {
          name = "config-volume"
          config_map {
            name = kubernetes_manifest.prometheus_configmap.metadata.0.name
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.prometheus_configmap]
}

resource "kubernetes_service" "prometheus_service" {
  metadata {
    name      = "prometheus-server"
    namespace = kubernetes_namespace.monitoring.metadata.0.name
  }
  spec {
    selector = {
      app = "prometheus"
    }
    ports {
      port        = 80
      target_port = 9090
      protocol    = "TCP"
      name        = "http"
    }
    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.prometheus_deployment]
}


resource "kubernetes_namespace" "grafana" {
  metadata {
    name = "grafana"
  }
}

resource "kubernetes_deployment" "grafana_deployment" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.grafana.metadata.0.name
    labels = {
      app = "grafana"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "grafana"
      }
    }
    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }
      spec {
        containers {
          name  = "grafana"
          image = "grafana/grafana:10.2.2" # 最新バージョンを確認
          ports {
            container_port = 3000
          }
        }
      }
    }
  }
  depends_on = [kubernetes_namespace.grafana]
}

resource "kubernetes_service" "grafana_service" {
  metadata {
    name      = "grafana"
    namespace = kubernetes_namespace.grafana.metadata.0.name
  }
  spec {
    selector = {
      app = "grafana"
    }
    ports {
      port        = 80
      target_port = 3000
      protocol    = "TCP"
      name        = "http"
    }
    type = "LoadBalancer" # LoadBalancer で外部公開
  }
  depends_on = [kubernetes_deployment.grafana_deployment]
}

resource "kubernetes_daemonset" "fluentd_daemonset" {
  metadata {
    name = "fluentd"
    namespace = "kube-system"
    labels = {
      app = "fluentd"
    }
  }
  spec {
    selector {
      match_labels = {
        app = "fluentd"
      }
    }
    template {
      metadata {
        labels = {
          app = "fluentd"
        }
      }
      spec {
        containers {
          name  = "fluentd"
          image = "public.ecr.aws/aws-observability/fluentd-for-aws:2.0.6" # 最新バージョンを確認
          env {
            name  = "AWS_REGION"
            value = var.aws_region
          }
          env {
            name  = "AWS_DEFAULT_REGION"
            value = var.aws_region
          }
          volume_mounts {
            name      = "varlog"
            mount_path = "/var/log"
          }
          volume_mounts {
            name      = "varlibdockercontainers"
            mount_path = "/var/lib/docker/containers"
            read_only = true
          }
        }
        volumes {
          name = "varlog"
          host_path {
            path = "/var/log"
          }
        }
        volumes {
          name = "varlibdockercontainers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
        service_account_name = "fluentd" # 必要に応じてServiceAccountを作成し、設定
      }
    }
  }
}

resource "kubernetes_service_account" "fluentd_service_account" {
  metadata {
    name      = "fluentd"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role" "fluentd_cluster_role" {
  metadata {
    name = "fluentd-cluster-role"
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "namespaces"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_cluster_role_binding" "fluentd_cluster_role_binding" {
  metadata {
    name = "fluentd-cluster-role-binding"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.fluentd_cluster_role.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.fluentd_service_account.metadata.0.name
    namespace = "kube-system"
  }
}
