# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-public-subnet-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.availability_zones, count.index)

  tags = {
    Name = "${var.prefix}-private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.prefix}-public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = element(aws_subnet.public, count.index).id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.prefix}-eks-cluster-sg-"
  vpc_id      = aws_vpc.main.id

  # EKS control plane to worker nodes communication
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow HTTPS from within VPC"
  }
  ingress {
    from_port   = 10250
    to_port     = 10252
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow kubelet and metrics-server"
  }
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
    description = "Allow metrics-server"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-eks-cluster-sg"
  }
}

resource "aws_security_group" "eks_worker" {
  name_prefix = "${var.prefix}-eks-worker-sg-"
  vpc_id      = aws_vpc.main.id

  # Allow worker nodes to communicate with the cluster control plane
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description = "Allow cluster control plane to worker nodes"
  }
  # Allow worker nodes to communicate with each other
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self = true
    description = "Allow worker nodes to communicate with each other"
  }
  # Allow SSH access from specified CIDRs
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_ssh_cidrs
    description = "Allow SSH access"
  }
  # Allow HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP access"
  }
  # Allow HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-eks-worker-sg"
  }
}
