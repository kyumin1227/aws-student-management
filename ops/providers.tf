terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  cloud {
    organization = "gsc-slack-app"

    workspaces {
      name = "aws-ops-test"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "ops-slack-app"
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}
