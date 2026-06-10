# Register Confluent Platform clusters with USM via Confluent Cloud REST API.
# The Confluent Terraform provider does not yet expose this resource type.

resource "terraform_data" "register_usm_kafka_cluster" {
  count = var.cp_node_count

  triggers_replace = [
    module.cp_node[count.index].cluster_id,
    confluent_api_key.cp_usm_key.id,
    confluent_environment.main.id,
  ]

  depends_on = [
    module.cp_node,
    confluent_api_key.cp_usm_key,
    confluent_role_binding.cp_usm,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/register_usm_kafka_cluster.sh"
    environment = {
      DISPLAY_NAME                        = "USM Demo cluster no ${count.index + 1}"
      CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID = module.cp_node[count.index].cluster_id
      CLOUD                               = lower(var.cloud_provider)
      REGION                              = var.region
      ENVIRONMENT_ID                      = confluent_environment.main.id
      USM_API_KEY                         = nonsensitive(var.confluent_cloud_api_key)
      USM_API_SECRET                      = nonsensitive(var.confluent_cloud_api_secret)
    }
  }
}

resource "terraform_data" "register_usm_connect_cluster" {
  count = var.cp_node_count
  triggers_replace = [
    module.cp_node[count.index].cluster_id,
    module.cp_node[count.index].connect_cluster_id,
    confluent_api_key.cp_usm_key.id,
    confluent_environment.main.id,
  ]

  depends_on = [
    module.cp_node,
    confluent_api_key.cp_usm_key,
    confluent_role_binding.cp_usm,
  ]

  provisioner "local-exec" {
    command = "${path.module}/scripts/register_usm_connect_cluster.sh"
    environment = {
      CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID   = module.cp_node[count.index].cluster_id
      CONFLUENT_PLATFORM_CONNECT_CLUSTER_ID = module.cp_node[count.index].connect_cluster_id
      CLOUD                               = lower(var.cloud_provider)
      REGION                              = var.region
      ENVIRONMENT_ID                      = confluent_environment.main.id
      USM_API_KEY                           = nonsensitive(var.confluent_cloud_api_key)
      USM_API_SECRET                        = nonsensitive(var.confluent_cloud_api_secret)
    }
  }
}
