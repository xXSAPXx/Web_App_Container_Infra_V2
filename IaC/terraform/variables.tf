
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


# Tailscale Kubernetes Operator - exposes Grafana directly onto the tailnet
# via a tailscale-class Ingress (see values/kube-prometheus-stack.yaml),
# instead of an internal ALB + a second external-dns + a new IRSA role.
# Needs an OAuth client (not a plain auth key - the operator creates/manages
# devices dynamically via the Tailscale API), created at
# https://login.tailscale.com/admin/settings/oauth with write scope on
# General/Services, Devices/Core, and Keys/Auth Keys, tagged tag:k8s-operator.
# Also needs a one-time tagOwners addition in the tailnet's ACL policy:
#   "tagOwners": { "tag:k8s-operator": [], "tag:k8s": ["tag:k8s-operator"] }
# and "HTTPS Certificates" enabled under the admin console's DNS page, or
# Grafana's Ingress will never get a valid cert. See the bastion module
# README for the full walkthrough.
variable "tailscale_oauth_client_id" {
  type        = string
  sensitive   = true
  description = "Tailscale OAuth client ID for the Kubernetes operator"
}

variable "tailscale_oauth_client_secret" {
  type        = string
  sensitive   = true
  description = "Tailscale OAuth client secret paired with tailscale_oauth_client_id"
}
