variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

variable "environment_name" {
  description = "Name of the Confluent Cloud environment"
  type        = string
  default     = "production"
}

variable "cluster_name" {
  description = "Name of the Enterprise Kafka cluster"
  type        = string
  default     = "enterprise-cluster"
}

variable "availability" {
  description = "Availability zone configuration (SINGLE_ZONE, MULTI_ZONE)"
  type        = string
  default     = "MULTI_ZONE"
  
  validation {
    condition     = contains(["SINGLE_ZONE", "MULTI_ZONE"], var.availability)
    error_message = "Availability must be either SINGLE_ZONE or MULTI_ZONE."
  }
}

variable "cloud_provider" {
  description = "Cloud provider (AWS, AZURE, GCP)"
  type        = string
  default     = "AWS"
  
  validation {
    condition     = contains(["AWS", "AZURE", "GCP"], var.cloud_provider)
    error_message = "Cloud provider must be AWS, AZURE, or GCP."
  }
}

variable "region" {
  description = "AWS region for the cluster (e.g., us-east-1, eu-west-1). NB USM ingress for telemetry reporting is currently only available in a reduced set of regions. See [list of supported regions](https://docs.confluent.io/cloud/current/usm/register/usm-network.html#aws-supported-regions)"
  type        = string
  default     = "us-east-1"
}

variable "owner_email" {
  description = "Email of the resource owner; applied as tag 'owner_email' on all AWS resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_endpoint_id" {
  description = "AWS VPC endpoint ID for the PrivateLink attachment connection (Interface endpoint ID)."
  type        = string
  default     = ""
}


variable "bastion_ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the bastion host (e.g. your office IP)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

variable "prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cp_node_count" {
  description = "Number of CP-Cluster node EC2 instances to create. Instances are distributed across available private subnets."
  type        = number
  default     = 1

  validation {
    condition     = var.cp_node_count >= 0 && var.cp_node_count <= 10
    error_message = "cp_node_count must be between 0 and 10."
  }
}

variable "cp_node_platform_image_tag" {
  description = "Docker image tag for Confluent Platform images on cp nodes (e.g. 7.6.0, latest)"
  type        = string
  default     = "latest"
}

variable "sync_images_to_ecr" {
  description = "When true, mirror unmodified images (broker, schema-registry, usm-agent, mosquitto) from Docker Hub to ECR, build the Connect image locally with plugins, and push it to ECR. Requires Docker and AWS CLI on the machine running Terraform. Set true once per image tag or Dockerfile change; cp_nodes then pull from ECR."
  type        = bool
  default     = false
}

variable "connect_image_rebuild_token" {
  description = "Change this value to force a Connect image rebuild on the next apply (requires sync_images_to_ecr = true), even when the Dockerfile and platform tag are unchanged."
  type        = string
  default     = ""
}

variable "connect_image_force_rebuild" {
  description = "When true with sync_images_to_ecr, rebuild the Connect image with docker build --no-cache (slower but ignores local Docker layer cache)."
  type        = bool
  default     = false
}

variable "usm_ccloud_endpoint" {
  description = "Confluent Cloud API host for USM agent (e.g. api.eu-north-1.AWS.private.confluent.cloud). Used for Route53 DNS and cp node config."
  type        = string
  default     = "FRONTDOOR_URL minus the leading 'api'"
}