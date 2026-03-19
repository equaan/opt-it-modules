module "s3" {
  source        = "../../../storage/s3"
  client_name   = "example-client"
  environment   = "dev"
  bucket_suffix = "uploads"
}

module "iam" {
  source      = "../../"
  client_name = "example-client"
  environment = "dev"

  ec2_s3_bucket_arns = [
    module.s3.bucket_arn,
    "${module.s3.bucket_arn}/*"
  ]
}

output "ec2_instance_profile_name" { value = module.iam.ec2_instance_profile_name }
