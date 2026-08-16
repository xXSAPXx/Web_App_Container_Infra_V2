
##################################################################
# IRSA role for Prometheus's own EC2 Service Discovery
# (prometheus.prometheusSpec.additionalScrapeConfigs' ec2_sd_configs in
# ../../values/kube-prometheus-stack.yaml). Prometheus itself calls
# ec2:DescribeInstances directly to find scrape targets (the bastion, or
# any future EC2 tagged Prometheus=true) - unlike ebs_csi/alb_controller,
# there's no AWS-managed policy for this, just one read-only action.
##################################################################

resource "aws_iam_role" "prometheus_irsa" {
  name = "${var.cluster_name}-prometheus-irsa"

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
            # Must match the ServiceAccount kube-prometheus-stack actually
            # creates for the Prometheus StatefulSet - confirmed via
            # `helm template` against this repo's actual release name
            # ("my-kube-prometheus-stack"), not guessed from the chart docs.
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:monitoring:my-kube-prometheus-stack-prometheus"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_policy" "prometheus_ec2_describe" {
  name        = "${var.cluster_name}-prometheus-ec2-describe"
  description = "Read-only EC2 describe access for Prometheus's ec2_sd_configs service discovery"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = "ec2:DescribeInstances",
        Resource = "*" # DescribeInstances doesn't support resource-level scoping
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "prometheus_irsa" {
  role       = aws_iam_role.prometheus_irsa.name
  policy_arn = aws_iam_policy.prometheus_ec2_describe.arn
}
