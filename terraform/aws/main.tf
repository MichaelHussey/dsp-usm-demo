terraform {
  required_version = ">= 1.2.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.74"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "aws" {
  region = var.region
  # Default tags to apply to all resources
  default_tags {
    tags = {
      Created_by  = "DSP USM Demo Terraform script"
      Project     = "DSP USM Demo Test"
      owner_email = var.owner_email
      divvy_last_modified_by = var.owner_email
    }
  }
}


resource "random_id" "env_display_id" {
    byte_length = 4
}
# ===============================
# SSH Key Pair for EC2 Access
# ===============================
module "keypair" {
  source = "./modules/aws_keypair"

  prefix          = var.prefix
  resource_suffix = random_id.env_display_id.hex
  output_path     = path.module
  common_tags = {
    Created_by  = "DSP USM Demo Terraform"
    Project     = "DSP USM Demo Test"
    owner_email = var.owner_email
  }
}
