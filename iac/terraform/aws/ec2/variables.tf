variable "client_name" {
  description = "The name of the client"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "vpc_id" {
  description = "VPC ID to launch the EC2 instance into"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the EC2 instance into"
  type        = string
}
