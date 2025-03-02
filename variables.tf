# variables.tf
variable "aws_region" {
  type        = string
  description = "AWSリージョン"
  default     = "ap-northeast-1"
}

variable "prefix" {
  type        = string
  description = "リソース名のプレフィックス"
  default     = "eks-app"
}

variable "availability_zones" {
  type        = list(string)
  description = "利用可能なAZ"
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "vpc_cidr_block" {
  type        = string
  description = "VPC CIDRブロック"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "パブリックサブネット CIDRブロック"
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "プライベートサブネット CIDRブロック"
  default     = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
}

variable "instance_type" {
  type        = string
  description = "EC2インスタンスタイプ"
  default     = "t3.medium"
}

variable "desired_capacity" {
  type        = number
  description = "ワーカーノードのDesired Capacity"
  default     = 3
}

variable "max_capacity" {
  type        = number
  description = "ワーカーノードのMax Capacity"
  default     = 10
}

variable "min_capacity" {
  type        = number
  description = "ワーカーノードのMin Capacity"
  default     = 2
}

variable "cluster_version" {
  type        = string
  description = "EKSクラスタのKubernetesバージョン"
  default     = "1.27" # 最新の安定バージョンを指定
}

variable "domain_name" {
  type        = string
  description = "Route53で管理するドメイン名 (例: example.com)"
  default     = "example.com" # 例としてexample.comを設定。実際にはRoute53で管理するドメインを指定
}

variable "subdomain_name" {
  type        = string
  description = "作成するサブドメイン名 (例: app.example.com の app)"
  default     = "app"
}

variable "acm_email" {
  type        = string
  description = "ACM証明書発行用メールアドレス"
  default     = "admin@example.com" # 例としてadmin@example.comを設定。実際には有効なメールアドレスを指定
}

variable "cloudfront_price_class" {
  type        = string
  description = "CloudFrontの料金クラス (PriceClass_All, PriceClass_200, PriceClass_100)"
  default     = "PriceClass_All"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "SSHアクセスを許可するCIDRリスト"
  default     = ["0.0.0.0/0"] # 運用環境では特定のIPアドレス範囲に限定することを推奨
}

variable "rds_instance_class" {
  type        = string
  description = "RDSインスタンスクラス"
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  type        = number
  description = "RDS 割り当てストレージ容量 (GB)"
  default     = 20
}

variable "rds_engine_version" {
  type        = string
  description = "RDS エンジンバージョン"
  default     = "mysql:8.0"
}

variable "redis_node_type" {
  type        = string
  description = "ElastiCache (Redis) ノードタイプ"
  default     = "cache.t3.micro"
}

variable "argo_cd_admin_password" {
  type        = string
  description = "Argo CD admin パスワード (Secrets Manager で管理することを推奨)"
  default     = "admin" # デフォルトパスワード。Secrets Manager等で管理することを強く推奨
  sensitive   = true
}

variable "secrets_manager_db_password_name" {
  type        = string
  description = "Secrets Manager に保存するDBパスワードのシークレット名"
  default     = "rds-master-password"
}
