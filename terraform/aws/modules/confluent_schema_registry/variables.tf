variable "environment_id" {
  description = "Confluent Cloud environment ID"
  type        = string
}

variable "cluster_name" {
  description = "Name prefix for Schema Registry service account and API key"
  type        = string
}

variable "context_prefix" {
  description = "Remote context prefix for USM schema forwarding (e.g. site1:.)"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS region for selecting the Schema Registry private endpoint"
  type        = string
}