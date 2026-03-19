output "instance_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.this.id
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.this.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance. Empty if instance is in a private subnet."
  value       = aws_instance.this.public_ip
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this.arn
}

output "instance_type" {
  description = "Instance type used."
  value       = aws_instance.this.instance_type
}

output "ami_id" {
  description = "AMI ID used for the instance."
  value       = aws_instance.this.ami
}
