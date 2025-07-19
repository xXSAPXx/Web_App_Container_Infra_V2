
# Configure Terraform Remote Backend: 
terraform {
  backend "s3" {
    bucket       = "terraform-main-backend-tfstate"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}


########################################################################################################################
## IaC to create the Teerraform Remote Backend in AWS: (Recommened to create the S3 Bucket by a separate bootstrap repo)
#
#
## Configure the AWS Provider and Region: 
#provider "aws" {
#  region = "us-east-1"
#}
#
## Create the S3 bucket to store the Terraform state file.
## It's recommended to enable versioning on this bucket to allow for state recovery.
#resource "aws_s3_bucket" "tfstate" {
#  bucket = "terraform-main-backend-tfstate"
#
#  # A block to prevent public access to this bucket.
#  # State files can contain sensitive information, so this is a crucial security measure.
#  resource "aws_s3_bucket_public_access_block" "tfstate_public_access" {
#    bucket = aws_s3_bucket.tfstate.id
#
#    block_public_acls       = true
#    block_public_policy     = true
#    ignore_public_acls      = true
#    restrict_public_buckets = true
#  }
#
#  # Enable versioning to keep a history of your state files.
#  # This protects against accidental deletions or corruption.
#  resource "aws_s3_bucket_versioning" "tfstate_versioning" {
#    bucket = aws_s3_bucket.tfstate.id
#    versioning_configuration {
#      status = "Enabled"
#    }
#  }
#
#  # Enable server-side encryption by default for all objects in the bucket.
#  # This corresponds to the `encrypt = true` setting in your backend block.
#  resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate_encryption" {
#    bucket = aws_s3_bucket.tfstate.id
#
#    rule {
#      apply_server_side_encryption_by_default {
#        sse_algorithm = "AES256"
#      }
#    }
#  }
#}
#
## S3: use_lockfile = true -->
## This prevents multiple users from running `terraform apply` at the same time, which could corrupt the state.
## Happy Coding! 