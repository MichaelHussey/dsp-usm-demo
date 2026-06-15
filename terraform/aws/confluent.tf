# Environment with Stream Governance Advanced (required for schema rules, contexts, etc.)
resource "confluent_environment" "main" {
  display_name = "${var.environment_name}-${random_id.env_display_id.hex}"

  stream_governance {
    package = "ADVANCED"
  }

  lifecycle {
    prevent_destroy = false
  }
}

module "confluent_schema_registry" {  
  source = "./modules/confluent_schema_registry"

  environment_id            = confluent_environment.main.id
  cluster_name                = var.cluster_name
  context_prefix              = var.cc_sr_context_prefix
  region                      = var.region
}
# Enterprise Kafka Cluster
resource "confluent_kafka_cluster" "enterprise" {
  display_name = var.cluster_name
  availability = var.availability
  cloud        = var.cloud_provider
  region       = var.region
  enterprise {}

  environment {
    id = confluent_environment.main.id
  }

  lifecycle {
    prevent_destroy = false
  }
}
# Inbound PrivateLink Gateway (replaces PLATT for connectivity from VPC to Confluent Cloud)
resource "confluent_gateway" "ingress" {
  display_name = "${var.cluster_name}-ingress-gateway"
  environment {
    id = confluent_environment.main.id
  }
  aws_ingress_private_link_gateway {
    region = var.region
  }
}

# Access Point registers our VPC endpoints with the gateway (enables connectivity)
resource "confluent_access_point" "ingress" {
  display_name = "${var.cluster_name}-ingress-ap"
  environment {
    id = confluent_environment.main.id
  }
  gateway {
    id = confluent_gateway.ingress.id
  }
  aws_ingress_private_link_endpoint {
    vpc_endpoint_id = aws_vpc_endpoint.privatelink.id
  } 
  depends_on = [confluent_gateway.ingress]
}

# Service Account for cluster management
resource "confluent_service_account" "cluster_admin" {
  display_name = "${var.cluster_name}-admin"
  description  = "Service account for managing ${var.cluster_name} cluster"
}

# ACL for service account - grant cluster admin permissions
resource "confluent_role_binding" "cluster_admin" {
  principal   = "User:${confluent_service_account.cluster_admin.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = confluent_kafka_cluster.enterprise.rbac_crn
}

# API Key for the service account
resource "confluent_api_key" "cluster_admin_key" {
  display_name = "${var.cluster_name}-admin-api-key"
  description  = "API key for ${var.cluster_name} cluster admin service account"
  owner {
    id          = confluent_service_account.cluster_admin.id
    api_version = confluent_service_account.cluster_admin.api_version
    kind        = confluent_service_account.cluster_admin.kind
  }
  # This is a workaround to avoid the issue with the Topic not being accessible on a private cluster
  disable_wait_for_ready = true

  depends_on = [confluent_access_point.ingress]

  managed_resource {
    id          = confluent_kafka_cluster.enterprise.id
    api_version = confluent_kafka_cluster.enterprise.api_version
    kind        = confluent_kafka_cluster.enterprise.kind

    environment {
      id = confluent_environment.main.id
    }
  }
}

# Service account and API key for cp node USM agent only (least privilege vs cluster admin)
resource "confluent_service_account" "cp_usm" {
  display_name = "${var.cluster_name}-cp-usm"
  description  = "Service account for cp node USM agent (${var.cluster_name})"
}

resource "confluent_role_binding" "cp_usm" {
  principal   = "User:${confluent_service_account.cp_usm.id}"
  role_name   = "UsmAgent"
  crn_pattern = confluent_environment.main.resource_name
}

resource "confluent_api_key" "cp_usm_key" {
  display_name = "${var.cluster_name}-cp-usm-api-key"
  description  = "API key for cp node USM agent (UsmAgent role only)"
  owner {
    id          = confluent_service_account.cp_usm.id
    api_version = confluent_service_account.cp_usm.api_version
    kind        = confluent_service_account.cp_usm.kind
  }
  disable_wait_for_ready = true

  depends_on = [
    confluent_role_binding.cp_usm,
    confluent_access_point.ingress,
  ]
}
