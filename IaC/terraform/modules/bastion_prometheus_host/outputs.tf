# Public IP of the Bastion Host Server: 
output "bastion_host_public_ip" {
  value = aws_instance.bastion_prometheus.public_ip
}
