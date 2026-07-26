
###################################################################################
# Generate a new base64 encoded userdata script for the Bastion_Host.
# With the private_dns_zone_id dynamic variable for hostname self-registration.
###################################################################################

locals {
  bastion_prometheus_host_userdata = templatefile("${path.module}/userdata_for_bastion_prometheus_host.tpl", {
    private_dns_zone_id = var.private_dns_zone_id
  })
}


########################################################################
# Public EC2 - Bastion / Jump_Host (SSH + DB connectivity testing):
########################################################################

resource "aws_instance" "bastion_prometheus" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.bastion_sec_group_ids
  key_name               = var.key_name
  user_data              = base64encode(local.bastion_prometheus_host_userdata)
  iam_instance_profile   = var.iam_instance_profile


  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  tags = {
    Name = var.bastion_host_tag_name
  }

}
