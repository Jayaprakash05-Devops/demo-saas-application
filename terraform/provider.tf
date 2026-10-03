terraform {
  required_version = ">= 1.15.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.36.0, < 7.0"
    }
  }
}