output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role. Empty if create_ec2_role = false."
  value       = var.create_ec2_role ? aws_iam_role.ec2[0].arn : ""
}

output "ec2_role_name" {
  description = "Name of the EC2 IAM role."
  value       = var.create_ec2_role ? aws_iam_role.ec2[0].name : ""
}

output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile. Pass to ec2 module as iam_instance_profile."
  value       = var.create_ec2_role ? aws_iam_instance_profile.ec2[0].name : ""
}

output "ec2_instance_profile_arn" {
  description = "ARN of the EC2 instance profile."
  value       = var.create_ec2_role ? aws_iam_instance_profile.ec2[0].arn : ""
}
