# psp.tf
resource "kubectl_manifest" "pod_security_standards_restricted" {
  yaml_body = <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: restricted-ns # Pod Security Standards を適用する Namespace
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: v1.27
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: v1.27
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: v1.27
YAML
}
