
# Lets GitHub Actions authenticate to AWS by assuming a role directly - no
# long-lived access keys stored as GitHub secrets. Lives in this persistent
# stack (not IaC/terraform/) for the same reason the ECR repos do: CI needs
# to be able to build/push an image even when the ephemeral cluster stack
# is destroyed - see backend.tf.
#
# thumbprint_list is deliberately omitted - since July 2023 AWS validates
# the OIDC provider's JWKS endpoint against its own trusted root CA list
# and ignores any thumbprint passed for github's provider, so specifying
# one is legacy/no-op with current provider versions.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
}

# WHO can assume the role - scoped to pushes to this repo's main branch
# only, not every branch/PR, and not any other GitHub repo. Broaden the
# sub condition later (e.g. to allow PR-triggered builds) only if
# something actually needs it.
data "aws_iam_policy_document" "ecr_push_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:xXSAPXx/Web_App_Container_Infra_V2:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "ecr_push" {
  name               = "github-actions-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.ecr_push_trust.json
}

# WHAT the role can do once assumed - ecr:GetAuthorizationToken has no
# resource-level permissions in AWS's own IAM model, so it must be "*"
# regardless of which repos you actually push to (documented AWS
# behavior, not a scoping mistake here). Every other action is scoped to
# just these two repo ARNs.
data "aws_iam_policy_document" "ecr_push_permissions" {
  statement {
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = [
      module.ecr.frontend_repository_arn,
      module.ecr.backend_repository_arn,
    ]
  }
}

resource "aws_iam_role_policy" "ecr_push_permissions" {
  name   = "ecr-push"
  role   = aws_iam_role.ecr_push.id
  policy = data.aws_iam_policy_document.ecr_push_permissions.json
}
