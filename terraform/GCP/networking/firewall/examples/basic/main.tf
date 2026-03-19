module "vpc" {
  source      = "../../vpc"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

module "firewall" {
  source      = "../../"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  vpc_name    = module.vpc.vpc_name
}

output "web_server_tag" { value = module.firewall.web_server_tag }
