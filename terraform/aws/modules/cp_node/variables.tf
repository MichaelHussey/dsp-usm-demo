# ===============================
# CP Node EC2 Module Variables
# ===============================

variable "cluster_name" {
  description = "Name of the cluster (used for resource naming)"
  type        = string
}

variable "instance_index" {
  description = "Index of this instance (for unique naming when multiple cp nodes)"
  type        = number
  default     = 0
}

variable "subnet_id" {
  description = "ID of the private subnet for the EC2 instance"
  type        = string
}

variable "security_group_ids" {
  description = "List of security group IDs for the EC2 instance"
  type        = list(string)
}

variable "key_name" {
  description = "Name of the SSH key pair for EC2 access"
  type        = string
}

variable "bootstrap_endpoint" {
  description = "Confluent Kafka cluster bootstrap endpoint"
  type        = string
}

variable "api_key" {
  description = "Confluent API key ID"
  type        = string
  sensitive   = true
}

variable "api_secret" {
  description = "Confluent API secret"
  type        = string
  sensitive   = true
}

variable "usm_api_key" {
  description = "Confluent API key ID for the USM agent (dedicated service account, UsmAgent role)"
  type        = string
  sensitive   = true
}

variable "usm_api_secret" {
  description = "Confluent API secret for the USM agent"
  type        = string
  sensitive   = true
}

variable "cc_environment_id" {
  description = "Confluent Cloud environment ID"
  type        = string
}

variable "usm_ccloud_endpoint" {
  description = "Confluent Cloud API host (e.g. https://confluent.cloud)"
  type        = string
  default     = "https://confluent.cloud"
}

variable "broker_image" {
  description = "Docker image for broker (e.g. confluentinc/cp-server:latest)"
  type        = string
}

variable "connect_image" {
  description = "Docker image for Connect (e.g. confluentinc/cp-server-connect:latest)"
  type        = string
}

variable "schema_registry_image" {
  description = "Docker image for Schema Registry (e.g. confluentinc/cp-schema-registry:latest)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}