# modules/secrets-manager/main.tf
resource "aws_secretsmanager_secret" "generic_secret" {
  name_prefix             = "${var.prefix}-generic-secret-"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "generic_secret_version" {
  secret_id     = aws_secretsmanager_secret.generic_secret.id
  version_stages = ["AWSCURRENT"]
  secret_string = jsonencode({
    key1 = "value1"
    key2 = "value2"
  })
}

# Kubernetes Secret を作成する例 (kubectl provider を使用)
resource "kubectl_manifest" "example_secret" {
  yaml_body = <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
  namespace: default # Secret を作成する Namespace
type: Opaque
data:
  key1: ${base64encode(jsondecode(aws_secretsmanager_secret_version.generic_secret_version.secret_string).key1)}
  key2: ${base64encode(jsondecode(aws_secretsmanager_secret_version.generic_secret_version.secret_string).key2)}
YAML
  depends_on = [aws_secretsmanager_secret_version.generic_secret_version]
}
