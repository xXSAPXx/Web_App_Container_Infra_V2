
# Configure Terraform Remote Backend: 
terraform {
  backend "s3" {
    bucket       = "terraform-main-container-backend-tfstate"
    key          = "terraform-container.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

