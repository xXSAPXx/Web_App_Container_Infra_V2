
# Output the instance profile for the Bastion Host:
output "bastion_instance_profile_name" {
  value = aws_iam_instance_profile.bastion.name
}
