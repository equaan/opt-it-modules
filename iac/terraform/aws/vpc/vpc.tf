module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "${{ values.client_name }}-vpc"
  
  # Uses the CIDR block provided by the DevOps engineer in the UI
  cidr = "${{ values.vpc_cidr }}"

  # Dynamically creates subnets based on the selected region
  azs             = ["${{ values.aws_region }}a", "${{ values.aws_region }}b"]
  private_subnets = [cidrsubnet("${{ values.vpc_cidr }}", 4, 0), cidrsubnet("${{ values.vpc_cidr }}", 4, 1)]
  public_subnets  = [cidrsubnet("${{ values.vpc_cidr }}", 4, 2), cidrsubnet("${{ values.vpc_cidr }}", 4, 3)]

  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "production"
  }
}
