
##################################################################
# IRSA role for the EBS CSI driver (the add-on below needs AWS
# permission to actually call CreateVolume/AttachVolume/DeleteVolume
# on your behalf whenever a PVC is created). Unlike the ALB
# Controller, AWS ships a ready-made managed policy for this one -
# no custom JSON to maintain.
##################################################################

resource "aws_iam_role" "ebs_csi_irsa" {
  name = "${var.cluster_name}-ebs-csi-irsa"

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
            # This is the exact service account name/namespace AWS's
            # EBS CSI driver add-on always creates for itself - the
            # trust policy has to match it exactly, or the driver's
            # pods can authenticate to AWS but get denied (wrong role).
            "${local.oidc_provider_url}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${local.oidc_provider_url}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_irsa" {
  role       = aws_iam_role.ebs_csi_irsa.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
