
output "rds_security_group_id" {
  description = "The ID of the RDS security group"
  value       = aws_security_group.rds_sg.id
}

output "bastion_host_security_group_id" {
  description = "The ID of the Bastion Host security group"
  value       = aws_security_group.bastion_prometheus_sg.id
}

output "alb_security_group_id" {
  description = "The ID of the ALB security group"
  value       = aws_security_group.alb_security_group.id
}

output "asg_security_group_id" {
  description = "The ID of the ASG security group"
  value       = aws_security_group.web_servers_sg.id
}