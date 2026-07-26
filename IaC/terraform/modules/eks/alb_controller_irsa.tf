
##################################################################
# IRSA role for the AWS Load Balancer Controller.
#
# NOTE: iam_policy_alb_controller.json is reconstructed from the
# well-known upstream policy shape (kubernetes-sigs/aws-load-balancer-
# controller). Diff it against the current official version at
# https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
# before applying to prod - the controller project revises this
# policy across releases.
##################################################################

data "aws_caller_identity" "current" {}

locals {
  oidc_provider_url = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "Permissions for the AWS Load Balancer Controller to manage ALBs/NLBs on behalf of Ingress/Service resources"
  policy      = file("${path.module}/iam_policy_alb_controller.json")
}

resource "aws_iam_role" "alb_controller_irsa" {
  name = "${var.cluster_name}-alb-controller-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller_irsa" {
  role       = aws_iam_role.alb_controller_irsa.name
  policy_arn = aws_iam_policy.alb_controller.arn
}
