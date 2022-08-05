provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

resource "aws_iam_role" "ms-cluster" {
  name = local.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "ms-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.ms-cluster.name
}


resource "aws_security_group" "ms-cluster" {
  name   = local.cluster_name
  vpc_id = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ms-up-running"
  }
}


resource "aws_eks_cluster" "ms-up-running" {
  name     = local.cluster_name
  role_arn = aws_iam_role.ms-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.ms-cluster.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.ms-cluster-AmazonEKSClusterPolicy
  ]
}


# Node Role
resource "aws_iam_role" "ms-node" {
  name = "${local.cluster_name}.node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Node Policy
resource "aws_iam_role_policy_attachment" "ms-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.ms-node.name
}

resource "aws_iam_role_policy_attachment" "ms-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.ms-node.name
}

resource "aws_iam_role_policy_attachment" "ms-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.ms-node.name
}


resource "aws_eks_node_group" "ms-node-group" {
  cluster_name    = aws_eks_cluster.ms-up-running.name
  node_group_name = "microservices"
  node_role_arn   = aws_iam_role.ms-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.ms-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.ms-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.ms-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}



# Create a kubeconfig file based on the cluster that has been created
resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG_END
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUMvakNDQWVhZ0F3SUJBZ0lCQURBTkJna3Foa2lHOXcwQkFRc0ZBREFWTVJNd0VRWURWUVFERXdwcmRXSmwKY201bGRHVnpNQjRYRFRJeU1EZ3dOVEF5TURNMU0xb1hEVE15TURnd01qQXlNRE0xTTFvd0ZURVRNQkVHQTFVRQpBeE1LYTNWaVpYSnVaWFJsY3pDQ0FTSXdEUVlKS29aSWh2Y05BUUVCQlFBRGdnRVBBRENDQVFvQ2dnRUJBT0pNCnh6SVBiRE1kVmZTcy9qTWQwY0hCbUNyWXdxamFFa3lLRnRvZU5nRE9BajZKeEcrU1Y0TDhYUG85UVQ0VWRsdEkKMno2cXdNL2ZLeGlkZTk3Vk1odzFHWjFtQWRpWlc4M25oWElzd0VuaDhTTVNSMytkVXlZcCsrRjNTR2lSNEhaeApub3NwT1RaZ2NWRU41K25haUdrRm5TMnJXdU9kUDB2dmN5c2NlTHk3ejdEczVDeW00QjVuUjZScDVRa3ppSkxECnZVdVN6Zk5LelhRRWU2UTF1S0dXc0o2VGtMbHEzQVhRVGphb1pGTVkxMHJKTmQ3UVRpT05yL0RtU0U3cUJNSE8KR0pySHN6ei9tK29WWk9kVDVLWm1sS1hoTkxLVm1tL2RQQ1FIbXBjTVZlYVFxdC9tbG5TQlFEYTg1aTlVRlBsbQpDalBMeURhTFBzUTRWeHFweTVNQ0F3RUFBYU5aTUZjd0RnWURWUjBQQVFIL0JBUURBZ0trTUE4R0ExVWRFd0VCCi93UUZNQU1CQWY4d0hRWURWUjBPQkJZRUZOLzNCS3pSSzlZU1BHby8xTzIvZzMxaFVNQzlNQlVHQTFVZEVRUU8KTUF5Q0NtdDFZbVZ5Ym1WMFpYTXdEUVlKS29aSWh2Y05BUUVMQlFBRGdnRUJBQ0lOYzRNMmtvVklZU0tZWDR0VwoxWFQrQW9RYkRUN0FnZllJeE42a3N0R0hLOWNXRGtsaW13c2gyUytRTWwwY2gzSWx3N2JmeGFIOGFpa2NJcEcwCkdlaUlIcHJCT3FyNVAyRnNzVUxlMURKcUFZSFE3SVQwck4wdFVhaUhoQnY1a0llSkZ2NzFPQ2N5NERHakJyOC8KTnJtQ2dXa1NWWGlWK0IzdDM5aDIrZEZ6cHRFd25zYzRxS29jZ2k5UGdCVEN1bWgyWFcwVTRyaVU3VkZGMll6cApNNDR0d3FaSit1YU83ckovZGZYY3ljNHhJME0xR1BaRnV3MlhsMk16ckdKWmVzQVBxb25Mc25XMEwxdTJEaVlXClN5SU9MNmQvbWJXZ0RRZXg4ZjdpakI3NXZqM2U1ZzdNUmFVeCs4V1BKK05LZ3lHRU9XRHFwM0VCb0hBc3h2TVkKZGZ3PQotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
    server: ${aws_eks_cluster.ms-up-running.endpoint}
  name: ${aws_eks_cluster.ms-up-running.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.ms-up-running.arn}
    user: ${aws_eks_cluster.ms-up-running.arn}
  name: ${aws_eks_cluster.ms-up-running.arn}
current-context: ${aws_eks_cluster.ms-up-running.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.ms-up-running.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.ms-up-running.name}"
    KUBECONFIG_END
  filename = "kubeconfig"
}