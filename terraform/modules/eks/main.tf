resource "aws_eks_cluster" "main" {
  name     = "solidarytech-cluster"
  role_arn = var.lab_role_arn

  vpc_config {
    subnet_ids = concat(var.public_subnets, var.private_subnets)
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "solidarytech-nodes"
  node_role_arn   = var.lab_eks_role_arn
  subnet_ids      = var.private_subnets

  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [ aws_eks_cluster.main ]
}
