
##############################################
# RDS Instance Configuration:
##############################################
variable "rds_instance_class" {
  type        = string
  description = "The instance type of the RDS database."
  default     = "db.t3.micro"
}

variable "rds_allocated_storage" {
  type        = number
  description = "The allocated storage in GBs for the RDS instance."
  default     = 20
}

variable "rds_engine" {
  type        = string
  description = "The database engine to use."
  default     = "mysql"
}

variable "rds_engine_version" {
  type        = string
  description = "The engine version to use."
  default     = "8.0.35"
}

variable "rds_port" {
  type        = number
  description = "Port on which the DB accepts connections."
  default     = 3306
}

variable "rds_snapshot_identifier" {
  type        = string
  description = "Identifier of the snapshot to restore the DB from."
}

variable "maintenance_window" {
  type        = string
  description = "RDS Maintenance Window Timeframe"
  default     = "mon:19:00-mon:19:30"
}

variable "rds_final_snapshot_identifier" {
  type        = string
  description = "Identifier for the final snapshot to create before deletion."
}

variable "rds_parameter_group_name" {
  type        = string
  description = "Name of the DB parameter group."
  default     = "default.mysql8.0"
}

variable "rds_storage_encrypted" {
  type        = bool
  description = "Is the RDS storage encrypted?"
  default     = true
}

variable "rds_publicly_accessible" {
  type        = bool
  description = "Dont allow public access!"
  default     = false
}

variable "rds_security_group_ids" {
  type        = list(string)
  description = "Sec_group id for the RDS Instance"
}

variable "rds_subnet_group_name" {
  type        = string
  description = "RDS Subnet Group ID"
}

variable "skip_final_snapshot" {
  type        = bool
  description = "CREATE or SKIP the final snapshot on instance termination"
  default     = false
}
