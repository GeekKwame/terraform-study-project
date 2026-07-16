terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket         = "jemimah-eddie-s3-164824552172-us-east-1-an"
    key            = "phase1/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "jemimah-edmund-tb"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

