terraform {
  required_version = "~> 1.16.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.68"
    }
  }

  backend "s3" {
    bucket       = "attendance-service-dev-tfstate-abc"
    key          = "global/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
