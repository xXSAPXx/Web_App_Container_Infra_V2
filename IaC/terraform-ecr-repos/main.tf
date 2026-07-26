
# Persistent ECR repositories - apply this ONCE, independent of the main
# IaC/terraform/ stack. See IaC/README.md for the full apply order.

module "ecr" {
  source = "../terraform/modules/ecr"

  repository_prefix = "calc-app"
  max_image_count   = 10
}
