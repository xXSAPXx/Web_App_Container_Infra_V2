
#########################################################################
# --- Cloudflare Variables for the Module --- (GLOBAL)
#########################################################################
variable "cloudflare_api_token" {
  type        = string
  description = "API token with DNS edit permissions"
  sensitive   = true
  nullable    = false
}

variable "cloudflare_zone_id" {
  type        = string
  description = "Zone ID for the Cloudflare domain"
  sensitive   = true
  nullable    = false
}

variable "select_domain_name" {
  type        = string
  description = "Domain name managed in Cloudflare (e.g., xxsapxx.uk)"
}

variable "alb_dns_name" {
  type        = string
  description = "The DNS name of the AWS ALB to point the CNAME record to"
}


#########################################################################
# --- Cloudflare_WWW_DNS_Record Variables--- 
#########################################################################
variable "comment" {
  type        = string
  description = "Comment for the DNS Record"
}

variable "sub_domain_name" {
  type        = string
  description = "Choose a subdomain for the DNS Record"
}

variable "dns_record_type" {
  type        = string
  description = "DNS Record Type"
  validation {
    condition     = contains(["A", "AAAA", "CNAME", "TXT"], var.dns_record_type)
    error_message = "Only A, AAAA, CNAME, or TXT record types are allowed."
  }
}

variable "dns_ttl" {
  type        = number
  description = "DNS TTL"
  validation {
    condition     = contains([1, 120, 300, 600, 900, 1800, 3600, 7200, 14400, 28800, 43200, 86400], var.dns_ttl)
    error_message = "TTL must be 1 (automatic) or one of Cloudflare’s supported TTL values."
  }
}

variable "proxied" {
  type        = bool
  description = "Proxied through CloudFlare: True/False"
}

#########################################################################
# --- Cloudflare_ROOT_to_WWW_DNS_Record Variables ---
#########################################################################
variable "root_domain_comment" {
  type        = string
  description = "Comment for the DNS Record"
}

variable "root_domain_name" {
  type        = string
  description = "Choose a subdomain for the DNS Record"
}

variable "root_dns_record_type" {
  type        = string
  description = "DNS Record Type"
  validation {
    condition     = contains(["A", "AAAA", "CNAME", "TXT"], var.root_dns_record_type)
    error_message = "Only A, AAAA, CNAME, or TXT record types are allowed."
  }
}

variable "root_dns_ttl" {
  type        = number
  description = "DNS TTL"
  validation {
    condition     = contains([1, 120, 300, 600, 900, 1800, 3600, 7200, 14400, 28800, 43200, 86400], var.root_dns_ttl)
    error_message = "TTL must be 1 (automatic) or one of Cloudflare’s supported TTL values."
  }
}

variable "root_proxied" {
  type        = bool
  description = "Proxied through CloudFlare: True/False"
}

#########################################################################
# --- Cloudflare_ROOT_to_WWW_DNS_Record Variables ---
#########################################################################
variable "rule_target" {
  type        = string
  description = "Target URL for the rule (Catches requests to: http://xxsapxx.uk, https://xxsapxx.uk, xxsapxx.uk/path, etc.)"
}

variable "rule_priority" {
  type        = number
  description = "The priority of the rule, used to define which Page Rule is processed over another. A higher number indicates a higher priority."
}

variable "rule_status" {
  type        = string
  description = "Status of the page rule"
}

variable "rule_redirect_to_url" {
  type        = string
  description = "Redirect traffic to this URL"
}

variable "rule_status_code" {
  type        = number
  description = "Permanent Redirect to 301"
  default     = 301
}

###########################################################################################################
# --- Use a redirect rule to enforce https:// (not just http → https at ALB level) --- Variables
###########################################################################################################
variable "setting_id" {
  type        = string
  description = "Name for the zone setting"
}

variable "always_use_https_value" {
  type        = string
  description = "Value for always_use_https ON / OFF"
  default     = "on"
}

###########################################################################################################
# 
###########################################################################################################
