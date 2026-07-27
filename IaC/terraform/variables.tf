
# Cloudflare Variables: 
variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token"
}

variable "cloudflare_zone_id" {
  type        = string
  sensitive   = true
  description = "Zone ID of the Cloudflare domain"
}

variable "cloudflare_domain_name" {
  type        = string
  sensitive   = true
  description = "Cloudflare Domain Name for Configuration"
}


# AWS Variables:
variable "aws_key_pair" {
  type        = string
  sensitive   = true
  description = "SSH KeyPair for the EC2 instances"
}


# Backend DB credentials - these match whatever admin user/password already
# exists inside the restored RDS snapshot (Terraform doesn't manage the DB's
# own users, so it can't derive these the way it derives rds_endpoint).
# Used to create the backend-db-secret Kubernetes Secret directly - no more
# manual `kubectl create secret` step.
variable "rds_db_username" {
  type        = string
  sensitive   = true
  description = "Username for the backend to connect to RDS with (must already exist in the restored snapshot)"
}

variable "rds_db_password" {
  type        = string
  sensitive   = true
  description = "Password for the backend to connect to RDS with (must already exist in the restored snapshot)"
}
