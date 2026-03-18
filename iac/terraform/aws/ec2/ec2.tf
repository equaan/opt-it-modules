# Fetches the latest Amazon Linux 2 AMI automatically
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux_2.id
  
  # Uses the instance size selected from the Backstage dropdown
  instance_type = "${{ values.ec2_instance_type }}"
  
  # If VPC is also selected, this attaches the EC2 instance to the private subnet
  # subnet_id     = module.vpc.private_subnets[0]

  tags = {
    Name = "${{ values.client_name }}-ec2-instance"
  }
}
