module "vpc" {
  source      = "../../../networking/vpc"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

module "firewall" {
  source      = "../../../networking/firewall"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  vpc_name    = module.vpc.vpc_name
}

module "gce" {
  source               = "../../"
  client_name          = "example-client"
  environment          = "dev"
  project_id           = "example-project-123456"
  region               = "us-central1"
  zone                 = "us-central1-a"
  subnetwork_self_link = module.vpc.private_subnet_self_link
  network_tags         = [module.firewall.web_server_tag]
}

output "internal_ip" { value = module.gce.internal_ip }
