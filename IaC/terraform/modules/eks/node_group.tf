
##################################################################
# IAM role for the worker nodes.
##################################################################

resource "aws_iam_role" "eks_node" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_read_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# SSM Session Manager access - shell into nodes without SSH/bastion hops.
resource "aws_iam_role_policy_attachment" "eks_ssm_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


##################################################################
# Launch template - only exists so we can attach the extra
# eks_node_sg (pod-to-pod / ALB-to-pod / bastion ICMP) alongside
# the EKS-managed cluster security group, and to enforce IMDSv2.
##################################################################

resource "aws_launch_template" "eks_node" {
  name_prefix = "${var.cluster_name}-node-"

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = var.node_disk_size
      volume_type = "gp3"
      encrypted   = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # Enforce IMDSv2
    http_put_response_hop_limit = 2
  }

  # Raises kubelet's --max-pods above what the AL2023 AMI's built-in
  # eni-max-pods.txt table would otherwise set. That table is static and
  # calculated without prefix delegation in mind, so even though vpc-cni
  # (see addons.tf) can now hand out far more IPs per node, kubelet would
  # still refuse to schedule past the old low ceiling unless told otherwise.
  #
  # Since no custom ami_id is set on the node group, EKS auto-generates the
  # rest of the nodeadm bootstrap (cluster endpoint/CA/join config) and just
  # merges this extra NodeConfig fragment into it - we only need to supply
  # the one field we're overriding.
  user_data = base64encode(<<-EOT
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: application/node.eks.aws

    ---
    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      kubelet:
        config:
          maxPods: ${var.node_max_pods}

    --BOUNDARY--
  EOT
  )

  # Supplying a launch template with explicit security groups stops EKS from
  # auto-attaching its own managed cluster security group to the nodes - that
  # SG carries the control-plane<->kubelet rules nodes need to actually join
  # the cluster, so it has to be listed here explicitly alongside our own.
  vpc_security_group_ids = [
    var.eks_node_security_group_id,
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
  ]

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-node"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}


##################################################################
# Managed Node Group - static sizing for this foundation pass.
# Karpenter (dynamic provisioning) replaces this in a later phase.
##################################################################

resource "aws_eks_node_group" "this" {
  cluster_name           = aws_eks_cluster.this.name
  node_group_name_prefix = "${var.cluster_name}-ng-"
  node_role_arn          = aws_iam_role.eks_node.arn
  subnet_ids             = var.private_subnet_ids
  instance_types         = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  launch_template {
    id      = aws_launch_template.eks_node.id
    version = aws_launch_template.eks_node.latest_version
  }

  # Same reasoning as the launch template above - a fixed node_group_name
  # would collide with itself on any replacement (instance_types, subnets,
  # etc. all force replacement), since AWS won't let two node groups share
  # a name even briefly. name_prefix + create_before_destroy lets the new
  # node group come up and take pods before the old one is torn down -
  # actual zero-downtime replacement instead of destroy-then-create.
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_policy,
    aws_iam_role_policy_attachment.eks_ssm_policy,
  ]
}
