
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


# NOTE: the www CNAME pointing at the ALB is NOT managed here - external-dns
# (running in-cluster) owns it, since it's the only thing that actually
# knows the ALB's DNS name and can react when it changes or the Ingress is
# deleted. See the helm_release.external_dns resource and its Cloudflare API
# token Secret in the root main.tf.
#
# The bare apex is different: external-dns's TXT-registry ownership scheme
# breaks for zone-apex CNAMEs (its "cname-<hostname>" ownership record
# collapses to "cname-xxsapxx.uk" with no separating dot, which fails its
# own zone-suffix match and never converges - visible as an endless
# UPDATE loop in its logs, retried every reconcile interval forever). So the
# apex is kept here instead, as a plain static CNAME to www.xxsapxx.uk (not
# to the ALB directly) - the target never changes session to session, so
# this needs no dynamic input and no manual step, same as everything else
# in this module.
resource "cloudflare_dns_record" "root_to_www" {
  zone_id = var.cloudflare_zone_id
  name    = var.select_domain_name
  type    = "CNAME"
  content = "www.${var.select_domain_name}"
  ttl     = 1 # Must be 1 ("Automatic") when proxied
  proxied = true
}


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

