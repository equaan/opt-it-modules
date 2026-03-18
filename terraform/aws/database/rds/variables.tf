variable "client_name" {
  description = "The name of the client"
  type        = string
}

variable "rds_engine" {
  description = "Database engine for RDS (mysql or postgres)"
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "vpc_id" {
  description = "VPC ID to deploy the RDS instance into"
  type        = string
}
