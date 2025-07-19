
##########################################
# PRIVATE DNS ZONE VARIABLE:
##########################################
variable "private_dns_zone_id" {
  type        = string
  sensitive   = true
  description = "Private DNS Zone ID for the Bastion Host to register its DNS record"
}


##########################################
# Grafana Connect Variables: 
##########################################

variable "prometheus_grafana_user" {
  type        = string
  sensitive   = true
  description = "Prometheus Grafana User"
}

variable "prometheus_grafana_api_key" {
  type        = string
  sensitive   = true
  description = "Prometheus Grafana API Key"
}


##########################################
# BASTION HOST VARIABLES 
##########################################

variable "ami_id" {
  description = "AMI ID to launch the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "Subnet ID to launch the EC2 instance in"
  type        = string
}

variable "bastion_sec_group_ids" {
  type        = list(string)
  description = "Sec_group id for the Bastion EC2"
}

variable "key_name" {
  description = "Key pair name for SSH access"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM Role for the Prometheus Automatic Service Discovery"
  type        = string
}

variable "volume_size" {
  description = "EBS Volume GBs Size"
  type        = number
  default     = 10
}

variable "volume_type" {
  description = "EBS Volume Type"
  type        = string
  default     = "gp2"
}

variable "bastion_host_tag_name" {
  description = "Tags to apply to the EC2 instance"
  type        = string
  default     = "Bastion-Prometheus-IaC"
}



