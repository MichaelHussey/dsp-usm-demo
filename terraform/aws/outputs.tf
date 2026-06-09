output "environment_id" {
  description = "ID of the Confluent Cloud environment"
  value       = confluent_environment.main.id
}

output "cluster_id" {
  description = "ID of the Enterprise Kafka cluster"
  value       = confluent_kafka_cluster.enterprise.id
}

output "cluster_bootstrap_endpoint" {
  description = "Bootstrap endpoint for the Kafka cluster"
  value       = confluent_kafka_cluster.enterprise.bootstrap_endpoint
}

output "cluster_rest_endpoint" {
  description = "REST API endpoint for the Kafka cluster"
  value       = confluent_kafka_cluster.enterprise.rest_endpoint
}

output "service_account_id" {
  description = "ID of the cluster admin service account"
  value       = confluent_service_account.cluster_admin.id
}

output "cp_usm_service_account_id" {
  description = "ID of the cp node USM service account (UsmAgent role only)"
  value       = confluent_service_account.cp_usm.id
}

output "cp_usm_api_key" {
  description = "API key for cp node USM agent (sensitive)"
  value       = confluent_api_key.cp_usm_key.id
  sensitive   = true
}

output "cp_usm_api_secret" {
  description = "API secret for cp node USM agent (sensitive)"
  value       = confluent_api_key.cp_usm_key.secret
  sensitive   = true
}

output "cluster_admin_api_key" {
  description = "API Key for the cluster (sensitive)"
  value       = confluent_api_key.cluster_admin_key.id
  sensitive   = true
}

output "cluster_admin_api_secret" {
  description = "API Secret for the cluster (sensitive)"
  value       = confluent_api_key.cluster_admin_key.secret
  sensitive   = true
}

output "bootstrap_servers" {
  description = "Bootstrap servers connection string (same as cluster_bootstrap_endpoint)"
  value       = [for endpoint in confluent_kafka_cluster.enterprise.endpoints : "accesspoint=${endpoint.access_point_id}, bootstrap=${endpoint.bootstrap_endpoint}, rest=${endpoint.rest_endpoint}, type=${endpoint.connection_type}"]
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "cp_nodes" {
  description = <<-EOT
    One object per cp node (order matches module.cp_node / count index).
    cluster_id is the KRaft broker CLUSTER_ID (Terraform UUID), not the Confluent Cloud cluster (see output cluster_id).
    connect_cluster_id is the Kafka Connect worker cluster ID (assigned at runtime on the cp_node).
    SSH assumes you are logged into the bastion; key path is ~/.ssh/<key_name>.pem on the bastion.
  EOT
  value = [for i, node in module.cp_node : {
    instance_index       = node.instance_index
    cluster_id           = node.cluster_id
    connect_cluster_id   = lookup(local.connect_cluster_ids, i, null)
    instance_id          = node.instance_id
    private_ip           = node.private_ip
    subnet_id            = node.subnet_id
    ssh_via_bastion_cmd  = "ssh -i ~/.ssh/${module.keypair.key_name}.pem ec2-user@${node.private_ip}"
  }]
}

output "connect_cluster_ids" {
  description = "Kafka Connect cluster IDs per cp_node index (same order as module.cp_node)"
  value       = local.connect_cluster_ids
}

output "ingress_gateway_id" {
  description = "ID of the Confluent inbound PrivateLink gateway"
  value       = confluent_gateway.ingress.id
}

output "ingress_access_point_id" {
  description = "ID of the Confluent ingress access point (registers VPC endpoints with gateway)"
  value       = confluent_access_point.ingress.id
}

output "vpc_endpoint_ids" {
  description = "IDs of the VPC endpoints for PrivateLink"
  value       = aws_vpc_endpoint.privatelink[*].id
}

output "route53_bootstrap_zone_id" {
  description = "Route53 private zone ID for bootstrap endpoint (derived from cluster bootstrap_endpoint)"
  value       = aws_route53_zone.bootstrap.zone_id
}

output "bastion_public_ip" {
  description = "Public IP of the bastion host (SSH here first, then to private EC2)"
  value       = aws_instance.bastion.public_ip
}

output "ssh_bastion_command" {
  description = "SSH command to connect to the bastion host"
  value       = "ssh -i ${module.keypair.private_key_path} ec2-user@${aws_instance.bastion.public_ip}"
}

output "usm_ccloud_endpoint" {
  description = "Confluent Cloud API host for USM agent (e.g. api.eu-north-1.AWS.private.confluent.cloud)"
  value       = aws_route53_record.usm_api.fqdn
}

output "bastion_ssh_key_name" {
  description = "Name of the bastion SSH key"
  value       = aws_secretsmanager_secret.bastion_ssh_key.name
}

output "ecr_registry" {
  description = "ECR registry URL for cp node images"
  value       = local.ecr_registry
}

output "ecr_images" {
  description = "ECR image URIs used by cp nodes"
  value       = local.ecr_images
}