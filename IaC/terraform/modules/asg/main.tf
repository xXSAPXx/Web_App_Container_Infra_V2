###################################################################################
# Generate a new base64 encoded userdata script for the lunch template.
# With Added Dynamic Variables for db_endpoint / private_dns_zone_id
# This script must be passed to the Launch Template! 
###################################################################################

locals {
  launch_template_userdata = templatefile("${path.module}/userdata_for_asg_launch_template.tpl", {
    db_endpoint         = var.database_endpoint
    private_dns_zone_id = var.private_dns_zone_id
  })
}


##################################################################
# Launch Template For Every EC2 Instance: 
##################################################################

resource "aws_launch_template" "web_server_template" {
  name_prefix   = var.launch_template_name_prefix
  image_id      = var.launch_template_image_id
  instance_type = var.launch_template_instance_type
  key_name      = var.launch_template_key_name
  user_data     = base64encode(local.launch_template_userdata)

  iam_instance_profile {
    name = var.launch_template_instance_profile
  }

  block_device_mappings {
    device_name = var.launch_template_device_name
    ebs {
      volume_size = var.launch_template_volume_size
      volume_type = var.launch_template_volume_type
    }
  }

  network_interfaces {
    security_groups = var.launch_template_security_groups
  }
}


##################################################################
# AUTO SCALING GROUP CREATION
##################################################################

resource "aws_autoscaling_group" "web_server_asg" {
  launch_template {
    id      = aws_launch_template.web_server_template.id
    version = aws_launch_template.web_server_template.latest_version

  }

  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity
  vpc_zone_identifier = var.asg_vpc_zone_identifier # Deploy EC2s in both private subnets

  # This ASG acts like a FRONTEND and BACKEND at the same time so we add both ALB target groups here: 
  target_group_arns = var.asg_target_group_arns

  tag {
    key                 = "Name"
    value               = var.asg_tag_name
    propagate_at_launch = var.asg_propagate_name_at_launch
  }

  health_check_type         = var.asg_health_check_type                 # ALB/ELB compatibility
  health_check_grace_period = var.asg_health_check_grace_period         # 5 minutes grace period for the instances to finish boot
  depends_on                = [aws_launch_template.web_server_template] # Ensure template is created before ASG
}



# Pass the dynamic variables from this module to main. 
# For userdata script debug purposes.
########################################################################

output "rds_endpoint_debug" {
  value = var.database_endpoint
}

output "private_dns_zone_debug" {
  value = var.private_dns_zone_id
}
