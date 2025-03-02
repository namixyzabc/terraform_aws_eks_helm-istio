# modules/elasticache/main.tf
resource "aws_elasticache_subnet_group" "redis_subnet_group" {
  name       = "${var.prefix}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids # プライベートサブネットを指定

  tags = {
    Name = "${var.prefix}-redis-subnet-group"
  }
}

resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.prefix}-redis-cluster"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1 # 必要に応じてノード数を変更
  subnet_group_name    = aws_elasticache_subnet_group.redis_subnet_group.name
  security_group_ids   = [var.redis_security_group_id] # ElastiCache 用セキュリティグループを指定
  engine_version       = "7.x" # Redis 7.x を指定。必要に応じてバージョンを変更
  maintenance_window = "Sun:03:00-Sun:04:00" # メンテナンスウィンドウの例
  snapshot_retention_limit = 7 # スナップショット保持期間 (日)

  tags = {
    Name = "${var.prefix}-redis-cluster"
  }
}


resource "aws_security_group" "redis_security_group" {
  name_prefix = "${var.prefix}-redis-sg-"
  vpc_id      = var.vpc_id

  # EKS ワーカーノードからの Redis アクセスを許可
  ingress {
    from_port       = 6379 # Redis のデフォルトポート
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.worker_security_group_id] # EKS ワーカーノードのセキュリティグループを指定
    description     = "Allow Redis access from EKS worker nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-redis-sg"
  }
}
