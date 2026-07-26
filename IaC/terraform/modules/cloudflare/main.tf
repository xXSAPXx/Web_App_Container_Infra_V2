
# Required Module Providers:
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}


# NOTE: the www/root CNAME records pointing at the ALB are NOT managed here
# anymore - external-dns (running in-cluster) owns them now, since it's the
# only thing that actually knows the ALB's DNS name and can react when it
# changes or the Ingress is deleted. See the helm_release.external_dns
# resource and its Cloudflare API token Secret in the root main.tf.
# This module only keeps the DNS-independent, always-on zone config below.


# Cloudflare Page Rule to Redirect traffic from ROOT to WWW: ---
resource "cloudflare_page_rule" "redirect_root_to_www" {
  zone_id  = var.cloudflare_zone_id
  target   = var.rule_target
  priority = var.rule_priority
  status   = var.rule_status

  actions = {
    forwarding_url = {
      url         = var.rule_redirect_to_url
      status_code = var.rule_status_code
    }
  }
}


# Use a redirect rule to enforce https:// (not just http → https at ALB level) -- Cloudflare: (Always Use HTTPS)
resource "cloudflare_zone_setting" "https" {
  zone_id    = var.cloudflare_zone_id
  setting_id = var.setting_id
  value      = var.always_use_https_value
}


# Enable HSTS (Strict-Transport-Security) in Cloudflare: (NOT AVAILABLE IN TERRAFORM)


# Rate Limiting Rules for DDoS Protection: ()

