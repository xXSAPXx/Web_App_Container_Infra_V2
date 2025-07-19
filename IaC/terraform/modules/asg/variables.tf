
############################################################################################
# Pass DB_ENDPOINT and PRIVATE_DNS_ZONE to Lunch Template User_Data_Script:
############################################################################################

variable "database_endpoint" {
  type        = string
  description = "The connection endpoint for the RDS instance."
}

variable "private_dns_zone_id" {
  type        = string
  description = "ID of the private Route53 hosted zone to pass to the ASG launch template."
}


#################### Launch Template Variables ###################
variable "launch_template_name_prefix" {
  description = "Prefix for the launch template name"
  type        = string
}

variable "launch_template_image_id" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0583d8c7a9c35822c"
}

variable "launch_template_instance_type" {
  description = "Instance type for EC2"
  type        = string
  default     = "t2.micro"
}

variable "launch_template_key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "launch_template_instance_profile" {
  description = "IAM Role for the Launch Template"
  type        = string
}

variable "launch_template_device_name" {
  description = "Device name for the root volume"
  type        = string
}

variable "launch_template_volume_size" {
  description = "Root EBS volume size (in GB)"
  type        = number
  default     = 10
}

variable "launch_template_volume_type" {
  description = "EBS volume type (e.g. gp2, gp3)"
  type        = string
  default     = "gp2"
}

variable "launch_template_security_groups" {
  description = "List of security group IDs for the launch template"
  type        = list(string)
}


################### Auto Scaling Group Variables ###################
variable "asg_min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
}

variable "asg_max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
}

variable "asg_desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
}

variable "asg_vpc_zone_identifier" {
  description = "List of subnet IDs for ASG placement"
  type        = list(string)
}

variable "asg_target_group_arns" {
  description = "List of ALB Target Group ARNs to attach to ASG"
  type        = list(string)
}

variable "asg_health_check_type" {
  description = "Type of health check to use (ELB recommended)"
  type        = string
  default     = "ELB"
}

variable "asg_health_check_grace_period" {
  description = "Health check grace period (in seconds)"
  type        = number
  default     = 300
}

variable "asg_tag_name" {
  description = "Name tag for ASG instances"
  type        = string
}

variable "asg_propagate_name_at_launch" {
  description = "Whether to propagate the Name tag at instance launch"
  type        = bool
  default     = true
}
