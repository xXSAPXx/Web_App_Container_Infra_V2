

variable "domain_name" {
  type        = string
  description = "The main domain to request a cert for"
}


variable "san" {
  type        = list(string)
  description = "Subject Alternative Names (e.g., www domain)"
}


variable "cloudflare_zone_id" {
  type        = string
  sensitive   = true
  description = "Zone ID for the Cloudflare domain"
}


variable "validation_method" {
  type        = string
  description = "SSL Cert Validation Method"
}