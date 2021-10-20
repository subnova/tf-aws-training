terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.63.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "eu-west-1"


  default_tags {
    tags = {
      Project = "tf-aws-training"
      Owner   = var.owner
    }
  }
}