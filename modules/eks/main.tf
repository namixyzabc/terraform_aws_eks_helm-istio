# modules/eks/main.tf
data "aws_availability_zones" "available" {}

module "vpc" {
  source = "../vpc"

  prefix               = var.prefix
  availability_zones = data.aws_availability_zones.available.names
  vpc_cidr_block       = var.vpc_cidr_block
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  allowed_ssh_cidrs    = var.allowed_ssh_cidrs
}

module "iam" {
  source = "../iam"
  prefix = var.prefix
}

resource "aws_eks_cluster" "cluster" {
  name     = "${var.prefix}-cluster"
  version  = var.cluster_version
  role_arn = module.iam.eks_cluster_role_arn
  vpc_config {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.eks_cluster_security_group_id]
  }

  depends_on = [module.vpc, module.iam]
}

resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "${var.prefix}-workers"
  node_role_arn   = module.iam.eks_worker_role_arn
  subnet_ids      = module.vpc.private_subnet_ids
  instance_types  = [var.instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }

  remote_access {
    ec2_ssh_key               = null # 必要に応じてSSHキーを設定
    source_security_group_ids = [module.vpc.eks_worker_security_group_id]
  }

  update_config {
    max_unavailable = 1
    max_unavailable_percentage = null
  }

  depends_on = [aws_eks_cluster.cluster, module.iam, module.vpc]
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.cluster.name
  name         = "vpc-cni"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.cluster.name
  name         = "coredns"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.cluster.name
  name         = "kube-proxy"
  resolve_conflicts = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.cluster.name
  name         = "aws-ebs-csi-driver"
  resolve_conflicts = "OVERWRITE"
}
