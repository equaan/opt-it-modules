terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  # This dynamically sets the region based on the Backstage form
  region = "${{ values.aws_region }}"

  # Applies these tags to every resource automatically
  default_tags {
    tags = {
      Client      = "${{ values.client_name }}"
      ManagedBy   = "Backstage"
    }
  }
}
