
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


# App Ingress DNS Variable:
# The ALB is provisioned dynamically by the AWS Load Balancer Controller from
# the k8s/ingress.yaml Ingress, not by Terraform - so this stays empty on the
# first apply. After `kubectl apply -f k8s/`, read the ALB hostname with
# `kubectl get ingress` and re-apply with this variable set to wire up Cloudflare DNS.
variable "app_alb_dns_name" {
  type        = string
  description = "DNS name of the ALB provisioned by the AWS Load Balancer Controller, once known"
  default     = ""
}
