
##################################################################
# EKS-managed add-ons (AWS handles the lifecycle/version updates
# instead of us self-installing these onto the nodes).
##################################################################

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_update = "OVERWRITE"

  # Turns on the add-on's built-in eBPF network policy agent, so plain
  # Kubernetes NetworkPolicy objects (see k8s/network-policies.yaml) actually
  # get enforced instead of silently doing nothing.
  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_node_group.this]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "coredns"
  resolve_conflicts_on_update = "OVERWRITE"

  # CoreDNS pods need somewhere to schedule.
  depends_on = [aws_eks_node_group.this]
}

# Lets pods actually request/get persistent storage (PVCs) - EBS volumes,
# provisioned/attached automatically. Not one of the add-ons EKS installs
# by default, unlike the three above - see modules/eks/ebs_csi_irsa.tf for
# the IAM role this needs to actually call the EC2 EBS APIs.
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = aws_iam_role.ebs_csi_irsa.arn

  # Its controller Deployment and node-plugin DaemonSet both need
  # somewhere to actually schedule, same reasoning as coredns/kube-proxy.
  depends_on = [aws_eks_node_group.this]
}
