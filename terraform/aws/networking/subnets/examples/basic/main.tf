# ─────────────────────────────────────────────────────────────
# EXAMPLE — Subnets for a dev environment
# Run: terraform init && terraform plan
# ─────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../../vpc"

  client_name = "example-client"
  environment = "dev"
  aws_region  = "us-east-1"
  vpc_cidr    = "10.0.0.0/16"
}

module "subnets" {
  source = "../../"

  client_name  = "example-client"
  environment  = "dev"
  aws_region   = "us-east-1"

  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr
  internet_gateway_id = module.vpc.internet_gateway_id
  nat_gateway_id      = module.vpc.nat_gateway_id

  public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]
  availability_zones   = ["us-east-1a", "us-east-1b"]
}

output "public_subnet_ids"  { value = module.subnets.public_subnet_ids }
output "private_subnet_ids" { value = module.subnets.private_subnet_ids }
