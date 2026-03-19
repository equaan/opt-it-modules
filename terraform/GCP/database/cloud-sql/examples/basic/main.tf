variable "db_password" {
  type      = string
  sensitive = true
}

module "vpc" {
  source      = "../../../networking/vpc"
  client_name = "example-client"
  environment = "dev"
  project_id  = "example-project-123456"
  region      = "us-central1"
}

module "cloud_sql" {
  source         = "../../"
  client_name    = "example-client"
  environment    = "dev"
  project_id     = "example-project-123456"
  region         = "us-central1"
  vpc_self_link  = module.vpc.vpc_self_link
  db_engine      = "postgres"
  admin_password = var.db_password
}

output "connection_name" { value = module.cloud_sql.connection_name }
