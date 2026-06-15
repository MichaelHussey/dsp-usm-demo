# Confluent Cloud Schema Registry credentials for on-prem CP Schema Registry forwarding.

data "confluent_schema_registry_cluster" "main" {
  environment {
    id = var.environment_id
  }
}

resource "confluent_service_account" "cp_sr" {
  display_name = "${var.cluster_name}-cp-sr"
  description  = "Service account for cp node Schema Registry forwarding to Confluent Cloud"
}

resource "confluent_role_binding" "cp_sr" {
  principal   = "User:${confluent_service_account.cp_sr.id}"
  role_name   = "DeveloperWrite"
  crn_pattern = "${data.confluent_schema_registry_cluster.main.resource_name}/subject=*"
}

resource "confluent_api_key" "cp_sr" {
  display_name = "${var.cluster_name}-cp-sr-api-key"
  description  = "Schema Registry API key for cp node schema forwarding"
  owner {
    id          = confluent_service_account.cp_sr.id
    api_version = confluent_service_account.cp_sr.api_version
    kind        = confluent_service_account.cp_sr.kind
  }

  managed_resource {
    id          = data.confluent_schema_registry_cluster.main.id
    api_version = data.confluent_schema_registry_cluster.main.api_version
    kind        = data.confluent_schema_registry_cluster.main.kind

    environment {
      id = var.environment_id
    }
  }

  depends_on = [confluent_role_binding.cp_sr]
}

data "confluent_endpoint" "sr" {
  filter {
    environment {
      id = var.environment_id
    }

    service    = "SCHEMA_REGISTRY"
    resource   = data.confluent_schema_registry_cluster.main.id
    cloud      = "AWS"         # "AWS" | "AZURE" | "GCP"
    region     = var.region        # e.g. "westus3"
    is_private = true
  }
}
locals {
  cc_sr_private_endpoint = one([
    for ep in data.confluent_endpoint.sr.endpoints : ep.endpoint
    if ep.endpoint_type == "REST"
    && ep.resource != null
    && ep.resource[0].id == data.confluent_schema_registry_cluster.main.id
  ])
}
resource "random_password" "password_encoder_secret" {
  length  = 32
  special = false
}
