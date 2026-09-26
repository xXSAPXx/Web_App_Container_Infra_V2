
###################################################################################
# Generate a new base64 encoded userdata script for the Bastion_Host.
###################################################################################

locals {
  bastion_prometheus_host_userdata = templatefile("${path.module}/userdata_for_bastion_prometheus_host.tpl", {
    tailscale_authkey = var.tailscale_authkey
  })
}

# The AWS provider's default_tags (Environment/Owner/Repo/...) - merged into
# the root volume's tags below, since default_tags don't reach block devices.
data "aws_default_tags" "current" {}


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

    # The provider's default_tags never reach block devices (tags_all stays
    # empty here), so merge them in explicitly - read from the provider
    # itself, so this can't drift from the rest of the stack.
    tags = merge(data.aws_default_tags.current.tags, {
      Name    = "${var.bastion_host_tag_name}-root"
      Service = "access"
    })
  }

  # IMDSv2 only - IMDSv1's plain HTTP GET (no token) is the classic
  # SSRF-to-credential-theft vector (a vulnerable app on this box could
  # be tricked into fetching http://169.254.169.254/... and handing an
  # attacker the instance's IAM credentials). The bastion's own userdata
  # already uses the token-based flow for its own IMDS calls, so this
  # doesn't change anything it actually does.
  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name       = var.bastion_host_tag_name
    Service    = "access"
    Prometheus = "true" # matches the ec2_sd_configs relabel filter in
    # values/kube-prometheus-stack.yaml - anything
    # without this tag is ignored, not just this box
  }

  # public_ip/public_dns perpetually re-diff to "(known after apply)" on
  # every plan under AWS provider v6.x, even though the value never
  # actually changes (confirmed live, same IP across multiple applies) -
  # a provider quirk, not real drift.
  lifecycle {
    ignore_changes = [public_ip, public_dns]
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
