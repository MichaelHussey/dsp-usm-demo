output "main" {
  description = "Confluent Cloud Schema Registry connection details for cp nodes"
  value = {
    endpoint                = data.confluent_schema_registry_cluster.main.rest_endpoint
    private_endpoint = coalesce(
      try(data.confluent_schema_registry_cluster.main.private_regional_rest_endpoints[var.region], null),
      data.confluent_schema_registry_cluster.main.rest_endpoint,
    )
    api_key                 = confluent_api_key.cp_sr.id
    api_secret              = confluent_api_key.cp_sr.secret
    context_prefix          = var.context_prefix
    password_encoder_secret = random_password.password_encoder_secret.result
  }
  sensitive = true
}
