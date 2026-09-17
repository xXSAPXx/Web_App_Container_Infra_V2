
################################################################################
# Custom parameter group - AWS's built-in default.mysql8.0 (used here
# previously) can't be edited at all, which is exactly why it's flagged by
# tflint's aws_db_instance_default_parameter_group rule. Empty for now (no
# non-default settings needed yet), but this is a real, ownable resource
# to actually tune later instead of a dead end.
################################################################################
resource "aws_db_parameter_group" "mydb" {
  name        = "calc-app-mysql8"
  family      = "mysql8.0" # matches rds_engine_version's major.minor - all 8.0.x versions share this family
  description = "Custom parameter group for calc-app's RDS instance"

  # A small, real app on db.t3.micro doesn't need RDS's default
  # memory-formula-derived max_connections (often much higher than this
  # instance could actually handle well) - pinned to a known, controlled
  # value instead of an implicit one.
  parameter {
    name  = "max_connections"
    value = "100"
  }

  # Slow query log - genuinely useful for observability given the
  # Prometheus/Grafana stack already built this session, not just a
  # default-for-defaults-sake setting.
  parameter {
    name  = "slow_query_log"
    value = "1"
  }

  # Threshold (seconds) above which a query is logged as slow - both are
  # dynamic parameters in MySQL 8.0, applied immediately, no reboot.
  parameter {
    name  = "long_query_time"
    value = "2"
  }

  parameter {
    name         = "performance_schema"
    value        = "1"
    apply_method = "pending-reboot"
  }
}


################################################################################
# Create an RDS Instance in the Private Subnet Group (2 private_subnets)
################################################################################
resource "aws_db_instance" "mydb" {
  # Custom RDS Name:
  identifier = var.rds_identifier

  engine            = var.rds_engine
  engine_version    = var.rds_engine_version
  instance_class    = var.rds_instance_class
  allocated_storage = var.rds_allocated_storage
  storage_encrypted = var.rds_storage_encrypted

  #db_name             = "CALC_APP_DB"         # No need since we restore from snapshot.
  #username            = "admin"               # No need since we restore from snapshot.
  #password            = "12345678"            # No need since we restore from snapshot.

  port                 = var.rds_port
  parameter_group_name = aws_db_parameter_group.mydb.name
  publicly_accessible  = var.rds_publicly_accessible

  vpc_security_group_ids = var.rds_security_group_ids
  db_subnet_group_name   = var.rds_subnet_group_name

  snapshot_identifier = var.rds_snapshot_identifier # Replace with your snapshot ID from which you want the DB to be created
  maintenance_window  = var.maintenance_window

  # Without this, modifications (renames, parameter group changes, etc.)
  # queue for the next maintenance_window instead of applying now - fine
  # for a real prod DB, but this lab gets built/destroyed same-session,
  # so a change deferred to "mon:19:00-mon:19:30" would just never happen.
  apply_immediately = true

  # Prevent deletion of the database
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.rds_final_snapshot_identifier

  # Snapshots (automated + final) inherit the instance's tags instead of
  # coming out untagged - otherwise they're anonymous blobs in the console
  # with no way to tell which app they belong to.
  copy_tags_to_snapshot = true
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


