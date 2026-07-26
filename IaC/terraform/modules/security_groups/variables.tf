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
  description = "Allow SSH for the bastion jump host"
  type        = string
  default     = "Allow SSH access for the bastion jump host"
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
# EKS NODE SEC_GROUP VARIABLES:
##############################################

variable "asg_sec_group_cidr_block" {
  type        = string
  description = "CIDR block used for ICMP ingress to the EKS node security group (e.g. bastion connectivity checks)."
  default     = "10.0.0.0/24"
}

variable "asg_security_group_name" {
  type        = string
  description = "EKS node Sec_Group Name."
  default     = "eks_node_sg"
}
