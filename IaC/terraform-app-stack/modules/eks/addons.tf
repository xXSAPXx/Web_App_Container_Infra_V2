
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
  #
  # ENABLE_PREFIX_DELEGATION makes each ENI slot hand out a /28 (16 IPs)
  # instead of a single IP, multiplying pod density per node without adding
  # nodes - see node_group.tf's user_data for the matching kubelet max-pods
  # override this depends on (the AMI's static eni-max-pods.txt table has no
  # idea prefix delegation is on, so it won't raise the pod ceiling on its
  # own). WARM_PREFIX_TARGET=1 is AWS's own recommended pairing - without it
  # ipamd's default warm-IP-target logic can over-allocate whole /28 prefixes
  # per warm IP it wants to keep spare, wasting address space in our subnets.
  configuration_values = jsonencode({
    enableNetworkPolicy = "true"
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
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


# Aggregates each node's kubelet stats (cAdvisor) into the cluster's
# "metrics.k8s.io" API - this is what `kubectl top nodes`/`kubectl top pods`
# and the HorizontalPodAutoscaler actually query. Not related to
# Prometheus/kube-prometheus-stack at all - that scrapes and *stores*
# time-series metrics for dashboards/alerting, this only ever holds the
# current live snapshot and forgets it immediately after. No IRSA role
# needed (unlike ebs_csi/alb_controller above) - it only reads kubelet's
# in-cluster stats endpoint, never calls an AWS API.
resource "aws_eks_addon" "metrics-server" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "metrics-server"
  resolve_conflicts_on_update = "OVERWRITE"

  # Its Deployment needs somewhere to schedule, same reasoning as
  # coredns/kube-proxy/ebs_csi above.
  depends_on = [aws_eks_node_group.this]
}