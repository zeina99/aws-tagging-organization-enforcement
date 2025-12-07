terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

################################################################################
# Provider Configuration
################################################################################

provider "aws" {
  region = var.region
  profile = "my-test-account"
  # assume_role {
  #   role_arn = "arn:aws:iam::${var.target_account_id}:role/${var.assume_role_name}"
  # }

  default_tags {
    tags = var.tags
  }
}