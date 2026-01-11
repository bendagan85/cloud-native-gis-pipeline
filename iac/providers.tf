terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 👇👇👇 החלק החדש: חיבור ל-S3 שיצרת 👇👇👇
  backend "s3" {
    bucket = "project-tf-state-ben-devops"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "GeoSpatial-Infrastructure"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}