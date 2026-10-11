# Credentials come from the standard AWS credential chain (e.g. AWS_PROFILE / SSO).
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      project = var.project
      env     = var.env
      owner   = var.owner
    }
  }
}
