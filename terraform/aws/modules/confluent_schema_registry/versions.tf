terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 2.74"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}
