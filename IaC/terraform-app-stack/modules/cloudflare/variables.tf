
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


#########################################################################
# --- Cloudflare Page Rule Variables ---
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
