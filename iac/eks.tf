# --- 1. IAM Role for EKS Cluster ---
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.environment}-eks-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# --- 2. IAM Role for Node Group ---
resource "aws_iam_role" "eks_node_role" {
  name = "${var.environment}-eks-node-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# הרשאות האוטומציה שכבר קיימות אצלך (מצוין!)
resource "aws_iam_role_policy_attachment" "eks_s3_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_sqs_access" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
  role       = aws_iam_role.eks_node_role.name
}

# --- 3. The EKS Cluster ---
resource "aws_eks_cluster" "main" {
  name     = "${var.environment}-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# 👇👇👇 התוספת החדשה: תבנית שמגדירה את ה-Hop Limit 👇👇👇
resource "aws_launch_template" "eks_nodes" {
  name = "${var.environment}-node-template"

  # מאפשר לפודים לדבר עם ה-Metadata Service (קריטי!)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2 
    instance_metadata_tags      = "enabled"
  }

  # חייבים להגדיר את זה כאן אם משתמשים ב-Launch Template
  instance_type = "t3.small"

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.environment}-eks-node"
    }
  }
}

# --- 4. Node Group (הכוח עבודה) ---
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.environment}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.private[*].id 

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  
  # חיבור ה-Launch Template החדש לקבוצה
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = "$Latest"
  }

  # הערה: כשמשתמשים ב-Launch Template, עדיף להסיר את instance_types מכאן ולהשאיר ב-Template,
  # או לוודא שהם תואמים. במקרה הזה הסרתי מכאן והעברתי ל-Template למעלה.
  capacity_type  = "SPOT"

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only,
    aws_iam_role_policy_attachment.eks_s3_access,
    aws_iam_role_policy_attachment.eks_sqs_access,
  ]
}

# --- Outputs ---
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}