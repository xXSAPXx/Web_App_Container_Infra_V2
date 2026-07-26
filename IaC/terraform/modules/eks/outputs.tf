
output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_ca_certificate" {
  description = "Base64-encoded cluster CA certificate, for configuring the kubernetes/helm providers."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_oidc_issuer_url" {
  value = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "node_role_arn" {
  value = aws_iam_role.eks_node.arn
}

output "cluster_security_group_id" {
  description = "The EKS-managed cluster primary security group (control-plane<->node ENI traffic)."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "alb_controller_irsa_role_arn" {
  value = aws_iam_role.alb_controller_irsa.arn
}
