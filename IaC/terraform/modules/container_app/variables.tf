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