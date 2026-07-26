
# Separate state from IaC/terraform/ on purpose - these ECR repos are meant
# to persist across every destroy/apply cycle of the ephemeral cluster stack,
# so images never need to be rebuilt/re-pushed just because the cluster was
# torn down and recreated.
terraform {
  backend "s3" {
    bucket       = "web-app-container-infra-v2-341587087009-us-east-1-an"
    key          = "terraform-ecr.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
