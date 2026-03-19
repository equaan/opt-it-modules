module "vpc" {
  source      = "../../"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

output "vpc_name"               { value = module.vpc.vpc_name }
output "private_subnet_self_link" { value = module.vpc.private_subnet_self_link }
