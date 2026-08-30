
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


# Tailscale VPN - the bastion joins as a subnet router (see
# modules/bastion_prometheus_host) advertising the VPC CIDR, giving private
# access to in-VPC-only services (Grafana, etc.) without managing our own
# WireGuard keys/config or opening an inbound port at all - Tailscale
# connects outbound and NAT-traverses via their coordination service.
# Generate an EPHEMERAL, REUSABLE auth key at
# https://login.tailscale.com/admin/settings/keys - ephemeral so the node
# auto-removes from the tailnet when the bastion is destroyed each session,
# reusable so the same key works across every fresh bastion, not just once.
variable "tailscale_authkey" {
  type        = string
  sensitive   = true
  description = "Tailscale ephemeral, reusable auth key the bastion uses to join the tailnet non-interactively"
}
