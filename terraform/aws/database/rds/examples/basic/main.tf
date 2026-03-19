module "vpc" {
  source      = "../../../networking/vpc"
  client_name = "example-client"
  environment = "dev"
}

module "subnets" {
  source              = "../../../networking/subnets"
  client_name         = "example-client"
  environment         = "dev"
  vpc_id              = module.vpc.vpc_id
  vpc_cidr            = module.vpc.vpc_cidr
  internet_gateway_id = module.vpc.internet_gateway_id
}

module "security_groups" {
  source      = "../../../networking/security-groups"
  client_name = "example-client"
  environment = "dev"
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = module.vpc.vpc_cidr
  rds_port    = 5432
}

module "rds" {
  source             = "../../"
  client_name        = "example-client"
  environment        = "dev"
  subnet_ids         = module.subnets.private_subnet_ids
  security_group_ids = [module.security_groups.database_security_group_id]
  engine             = "postgres"
  master_password    = "changeme123"  # use secrets manager in real usage
}

output "db_endpoint" { value = module.rds.db_endpoint }
