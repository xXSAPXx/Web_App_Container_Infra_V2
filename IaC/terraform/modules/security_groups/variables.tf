##############################################
# ALL SEC_GROUPS VARIABLES:
##############################################

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where the security groups will be created."
}


##############################################
# RDS INSTANCE SEC_GROUP VARIABLES:
##############################################

variable "rds_cidr_block" {
  type        = string
  description = "CIDR block used for ingress and egress inside the VPC."
  default     = "10.0.0.0/24"
}

variable "rds_security_group_name" {
  type        = string
  description = "Name for the RDS Security Group"
  default     = "RDS_SG_IaC"
}


#########################################
# BASTION HOST SEC GROUP VARIABLES: 
#########################################

variable "sec_group_name" {
  description = "Name for the Bastion EC2"
  type        = string
  default     = "bastion_prometheus_sg"
}

variable "sec_group_description" {
  description = "Allow SSH and Prometheus and Node_Exporter Ports"
  type        = string
  default     = "Allow SSH and Prometheus and Node_Exporter Ports"
}

variable "bastion_host_cidr_block" {
  type        = string
  description = "CIDR block used for ingress and egress inside the VPC."
  default     = "0.0.0.0/0"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block for the VPC."
}

##############################################
# ALB SEC_GROUP VARIABLES:
##############################################

variable "alb_sec_group_cidr_block" {
  type        = string
  description = "CIDR block used for ingress and egress for the Public ALB."
  default     = "0.0.0.0/0"
}

variable "alb_security_group_name" {
  type        = string
  description = "ALB Sec_Group Name."
  default     = "alb_security_group"
}

##############################################
# ASG (Web_Servers) SEC_GROUP VARIABLES:
##############################################

variable "asg_sec_group_cidr_block" {
  type        = string
  description = "CIDR block used for ingress and egress for the Web_Servers."
  default     = "10.0.0.0/24"
}

variable "bastion_host_sec_group" {
  type        = list(string)
  description = "Only this SEC_Group will be allowed to connect to the WEB_SERVERS in the ASG."
}

variable "asg_security_group_name" {
  type        = string
  description = "ASG Sec_Group Name."
  default     = "asg_servers_sg"
}
