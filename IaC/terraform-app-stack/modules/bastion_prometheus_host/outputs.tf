# Public IP of the Bastion Host Server:
output "bastion_host_public_ip" {
  value = aws_instance.bastion_prometheus.public_ip
}

# Stable private DNS name for the Bastion Host (doesn't change across
# destroy/recreate cycles the way the old IP-embedded self-registered name did):
output "bastion_private_dns_name" {
  value = aws_route53_record.bastion.name
}
