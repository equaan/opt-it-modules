# ─────────────────────────────────────────────────────────────
# EXAMPLE — Basic VPC for a dev environment
# Run: terraform init && terraform plan
# ─────────────────────────────────────────────────────────────

module "vpc" {
  source = "../../"

  client_name = "example-client"
  environment = "dev"
  aws_region  = "us-east-1"

  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false   # not needed for dev
}

output "vpc_id" {
  value = module.vpc.vpc_id
}
