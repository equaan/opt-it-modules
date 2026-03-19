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
}

module "ec2" {
  source             = "../../"
  client_name        = "example-client"
  environment        = "dev"
  subnet_id          = module.subnets.private_subnet_ids[0]
  security_group_ids = [module.security_groups.web_security_group_id]
  instance_type      = "t3.micro"
}

output "instance_id" { value = module.ec2.instance_id }
