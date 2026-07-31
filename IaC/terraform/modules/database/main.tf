
################################################################################
# Create an RDS Instance in the Private Subnet Group (2 private_subnets)
################################################################################
resource "aws_db_instance" "mydb" {
  engine            = var.rds_engine
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  storage_encrypted = var.rds_storage_encrypted

  #db_name             = "CALC_APP_DB"         # No need since we restore from snapshot.
  #username            = "admin"               # No need since we restore from snapshot.
  #password            = "12345678"            # No need since we restore from snapshot.

  port                 = var.rds_port
  parameter_group_name = var.rds_parameter_group_name
  publicly_accessible  = var.rds_publicly_accessible

  vpc_security_group_ids = var.rds_security_group_ids
  db_subnet_group_name   = var.rds_subnet_group_name

  snapshot_identifier = var.rds_snapshot_identifier # Replace with your snapshot ID from which you want the DB to be created 
  maintenance_window  = var.maintenance_window

  # Prevent deletion of the database
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.rds_final_snapshot_identifier
}


################################################################################
# Private DNS record for RDS - Terraform-managed, same reasoning as the
# bastion's: RDS auto-generates a new endpoint hostname every time this
# instance is recreated (restoring from a snapshot into a fresh instance,
# same as every session in this repo), so a stable alias decouples the app
# (and anyone connecting manually) from whatever hostname RDS happened to
# generate this time. Multi-AZ failover itself doesn't need this - AWS
# already repoints the RDS endpoint's own DNS record automatically for
# that case - this is for the cases AWS doesn't handle: fresh restores,
# Blue/Green cutovers, migrating to a different instance entirely.
################################################################################
resource "aws_route53_record" "rds" {
  zone_id = var.private_dns_zone_id
  name    = "${var.db_dns_name}.${var.private_dns_zone_name}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_db_instance.mydb.address]
}


