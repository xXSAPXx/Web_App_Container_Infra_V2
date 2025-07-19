
###################################################################################
# Generate a new base64 encoded userdata script for the Bastion_Prometheus_Host.
# With Added Dynamic Variables for prometheus_grafana_user / prometheus_grafana_api_key / private_dns_zone_id
# This script must be passed to the Bastion_Prometheus_EC2 instance.
###################################################################################

locals {
  bastion_prometheus_host_userdata = templatefile("${path.module}/userdata_for_bastion_prometheus_host.tpl", {
    private_dns_zone_id        = var.private_dns_zone_id
    prometheus_grafana_user    = var.prometheus_grafana_user
    prometheus_grafana_api_key = var.prometheus_grafana_api_key
  })
}


########################################################################
# Public EC2 - Jump_Host + Prometheus server:
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
