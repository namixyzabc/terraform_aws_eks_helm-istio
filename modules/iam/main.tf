# modules/iam/main.tf
resource "aws_iam_role" "eks_cluster" {
  name_prefix = "${var.prefix}-eks-cluster-role-"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role_name  = aws_iam_role.eks_cluster.name
}

resource "aws_iam_role" "eks_worker" {
  name_prefix = "${var.prefix}-eks-worker-role-"
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_policy_attachment" "eks_worker_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role_name  = aws_iam_role.eks_worker.name
}

resource "aws_iam_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role_name  = aws_iam_role.eks_worker.name
}

resource "aws_iam_policy_attachment" "ec2_readonly_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
  role_name  = aws_iam_role.eks_worker.name
}

resource "aws_iam_policy_attachment" "ecr_pull_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role_name  = aws_iam_role.eks_worker.name
}

resource "aws_iam_instance_profile" "eks_worker_profile" {
  name_prefix = "${var.prefix}-eks-worker-profile-"
  role      = aws_iam_role.eks_worker.name
}
