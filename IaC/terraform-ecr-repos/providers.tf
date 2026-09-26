
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.63"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  # Applied to every taggable resource in this root. Resource-level tags
  # win on key collisions, so resources belonging to a different Service
  # override just that key. Environment is "shared", not a variable: the
  # registry and CI role serve every environment - images are built once
  # and promoted, not rebuilt per env.
  default_tags {
    tags = {
      Environment = "shared"
      Service     = "platform"
      Owner       = var.owner
      Repo        = var.repository
      ManagedBy   = "terraform"
    }
  }
}
