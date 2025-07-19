
output "subdomain_to_alb_cname_record" {
  value = cloudflare_dns_record.subdomain_to_alb_record.name
}

output "root_domain_to_alb_cname_record" {
  value = cloudflare_dns_record.root_domain_to_alb_record.name
}