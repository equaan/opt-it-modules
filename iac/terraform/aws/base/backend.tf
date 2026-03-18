terraform {
  backend "s3" {
    # This should be your company's central Terraform state bucket
    bucket = "company-central-terraform-state-bucket" 
    
    # Creates a unique folder for every client automatically
    key    = "clients/${{ values.client_name }}/terraform.tfstate"
    region = "us-east-1"
  }
}
