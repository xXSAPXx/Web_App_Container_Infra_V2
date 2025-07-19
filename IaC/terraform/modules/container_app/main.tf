










# Pass the dynamic variables from this module to main. 
# For userdata script debug purposes.
########################################################################

output "rds_endpoint_debug" {
  value = var.database_endpoint
}

output "private_dns_zone_debug" {
  value = var.private_dns_zone_id
}