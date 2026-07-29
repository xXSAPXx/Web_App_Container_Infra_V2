
###################################################################################
# Generate a new base64 encoded userdata script for the Bastion_Host.
###################################################################################

locals {
  bastion_prometheus_host_userdata = templatefile("${path.module}/userdata_for_bastion_prometheus_host.tpl", {})
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


  root_block_device {
    volume_size = var.volume_size
    volume_type = var.volume_type
  }

  tags = {
    Name = var.bastion_host_tag_name
  }

}


########################################################################
# Private DNS record for the bastion - Terraform-managed since this is a
# single static instance whose lifecycle Terraform already fully controls
# (as opposed to a dynamic ASG, where something has to react to real-time
# scale events instead - that's what AWS Cloud Map is for). Replaces a
# boot-time shell script that self-registered via `aws route53
# change-resource-record-sets` and had no matching cleanup on termination,
# leaving stale records behind on every destroy/recreate cycle.
########################################################################

resource "aws_route53_record" "bastion" {
  zone_id = var.private_dns_zone_id
  name    = "${var.bastion_dns_name}.${var.private_dns_zone_name}"
  type    = "A"
  ttl     = 120
  records = [aws_instance.bastion_prometheus.private_ip]
}
