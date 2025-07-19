
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


# This means AWS will provide a DNS CNAME record that you must create (manually or via Terraform) 
# in your domain's DNS (e.g., Cloudflare, Route 53) to prove ownership before the cert is issued.
resource "aws_acm_certificate" "alb_cert" {
  domain_name               = var.domain_name
  subject_alternative_names = var.san # Added the www subdomain here
  validation_method         = var.validation_method

  tags = {
    Environment = "prod"
  }

  lifecycle {
    create_before_destroy = true
  }
}


# Create DNS validation record in Cloudflare:
resource "cloudflare_dns_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.alb_cert.domain_validation_options : dvo.domain_name => {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  }
  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.value
  ttl     = 60
  proxied = false # IMPORTANT: Validation records MUST NOT be proxied by Cloudflare

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



# Wait for the certificate to be validated and issued:
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.alb_cert.arn

  validation_record_fqdns = [
    for record in cloudflare_dns_record.cert_validation : record.name
  ]

  lifecycle { # Prevent RE-Deployment of CloudFlare resource every time we terraform plan
    ignore_changes = [
      id,
      validation_record_fqdns,
    ]
  }
}     