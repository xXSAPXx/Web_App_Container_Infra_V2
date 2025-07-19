
# Output the instance profile for the Prometheus Server: 
output "prometheus_server_instance_profile_name" {
  value = aws_iam_instance_profile.prometheus.name
}


# Output the instance profile for the ASG Web-Servers: 
output "launch_template_instance_profile_name" {
  value = aws_iam_instance_profile.dns_registration_instance_profile.name
}
