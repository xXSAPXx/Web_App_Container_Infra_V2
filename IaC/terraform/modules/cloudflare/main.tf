
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


# Change Cloudflare DNS Records to point to the AWS ALB DNS Name: 
resource "cloudflare_dns_record" "subdomain_to_alb_record" {
  zone_id = var.cloudflare_zone_id # Domain Zone ID
  comment = var.comment            #
  name    = var.sub_domain_name    # Creates www.xxsapxx.uk
  type    = var.dns_record_type    # ALB doesn't have static IP, use CNAME
  content = var.alb_dns_name       # Attach DNS Record to AWS ALB CNAME
  ttl     = var.dns_ttl            # DNS Record TTL 
  proxied = var.proxied            # Enables Cloudflare HTTPS + caching

  lifecycle { # Prevent RE-Deployment of CloudFlare resource every time we terraform plan
    ignore_changes = [
      name,
      content,
      meta,
      modified_on,
      created_on,
      comment,
      comment_modified_on,
      settings,
      proxiable,
      tags,
      tags_modified_on,
    ]
  }
}


# Change Cloudflare ROOT Record to point to the AWS ALB DNS Name: 
resource "cloudflare_dns_record" "root_domain_to_alb_record" {
  zone_id = var.cloudflare_zone_id   # Domain Zone ID
  comment = var.root_domain_comment  #
  name    = var.root_domain_name     # Creates xxsapxx.uk
  type    = var.root_dns_record_type # ALB doesn't have static IP, use CNAME
  content = var.alb_dns_name         # Attach DNS Record to AWS ALB CNAME
  ttl     = var.root_dns_ttl         # DNS Record TTL 
  proxied = var.root_proxied         # Enables Cloudflare HTTPS + caching

  lifecycle { # Prevent RE-Deployment of CloudFlare resource every time we terraform plan
    ignore_changes = [
      name,
      content,
      meta,
      modified_on,
      created_on,
      comment,
      comment_modified_on,
      settings,
      proxiable,
      tags,
      tags_modified_on,
    ]
  }
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

