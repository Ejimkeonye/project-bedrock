variable "cluster_version" { type = string }
variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }

resource "aws_iam_role" "cluster" {
  name = "project-bedrock-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/project-bedrock-cluster/cluster"
  retention_in_days = 7
}

resource "aws_eks_cluster" "this" {
  name     = "project-bedrock-cluster"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_public_access   = true
    endpoint_private_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode = "API"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy, aws_cloudwatch_log_group.eks]
}

resource "aws_iam_role" "node" {
  name = "project-bedrock-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "project-bedrock-nodes"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 2
  }
}

data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "cluster_name" { value = aws_eks_cluster.this.name }
output "cluster_endpoint" { value = aws_eks_cluster.this.endpoint }
output "oidc_issuer_url" { value = aws_eks_cluster.this.identity[0].oidc[0].issuer }
output "oidc_provider_arn" { value = aws_iam_openid_connect_provider.eks.arn }
output "cluster_security_group_id" { value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id }
output "node_security_group_id" { value = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id }
