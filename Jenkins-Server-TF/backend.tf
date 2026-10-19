terraform {
  backend "s3" {
    bucket         = "princethedev"
    region         = "us-east-1"
    key            = "terraform.tfstate"
    use_lockfile   = true
    encrypt        = true
  }
  required_version = ">=1.10.0"
  required_providers {
    aws = {
      version = ">= 2.7.0"
      source  = "hashicorp/aws"
    }
  }
}
