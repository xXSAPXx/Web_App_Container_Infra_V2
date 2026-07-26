
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
