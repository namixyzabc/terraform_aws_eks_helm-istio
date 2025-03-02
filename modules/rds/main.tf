# modules/rds/main.tf
resource "aws_secretsmanager_secret" "rds_master_password" {
  name_prefix = "${var.prefix}-rds-password-"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "rds_master_password_version" {
  secret_id     = aws_secretsmanager_secret.rds_master_password.id
  version_stages = ["AWSCURRENT"]
  secret_string = random_password.rds_password.result
}

resource "random_password" "rds_password" {
  length              = 20
  special             = true
  override_special    = "!#$%&*()-_=+[]{}?:"
}


resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "${var.prefix}-rds-subnet-group"
  subnet_ids = var.private_subnet_ids # プライベートサブネットを指定

  tags = {
    Name = "${var.prefix}-rds-subnet-group"
  }
}


resource "aws_db_instance" "rds_instance" {
  allocated_storage    = var.rds_allocated_storage
  instance_class       = var.rds_instance_class
  engine               = split(":", var.rds_engine_version)[0]
  engine_version       = split(":", var.rds_engine_version)[1]
  db_name              = "mydb"
  username             = "admin"
  password             = aws_secretsmanager_secret_version.rds_master_password_version.secret_string
  parameter_group_name = "default.mysql8.0" # 必要に応じてパラメータグループを指定
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [var.rds_security_group_id] # RDS用セキュリティグループを指定
  multi_az             = true # マルチAZ構成
  backup_retention_period = 7 # バックアップ保持期間 (日)
  skip_final_snapshot  = true

  tags = {
    Name = "${var.prefix}-rds-instance"
  }
}

resource "aws_security_group" "rds_security_group" {
  name_prefix = "${var.prefix}-rds-sg-"
  vpc_id      = var.vpc_id

  # EKS ワーカーノードからの MySQL/Aurora アクセスを許可
  ingress {
    from_port       = 3306 # MySQL/Aurora のデフォルトポート
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.worker_security_group_id] # EKS ワーカーノードのセキュリティグループを指定
    description     = "Allow MySQL/Aurora access from EKS worker nodes"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-rds-sg"
  }
}
