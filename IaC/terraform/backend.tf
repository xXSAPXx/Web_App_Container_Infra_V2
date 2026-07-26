
# Configure Terraform Remote Backend: 
terraform {
  backend "s3" {
    bucket       = "web-app-container-infra-v2-341587087009-us-east-1-an"
    key          = "terraform-container-infra-v2.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

