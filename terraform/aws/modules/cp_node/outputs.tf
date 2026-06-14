# ===============================
# CP Node EC2 Module Outputs
# ===============================

output "instance_index" {
  description = "Index of this cp node (matches Terraform count)"
  value       = var.instance_index
}

output "subnet_id" {
  description = "Private subnet ID for this instance"
  value       = var.subnet_id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.cp_node.id
}

output "private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.cp_node.private_ip
}

output "cluster_id" {
  description = "KRaft CLUSTER_ID for this cp broker (Terraform random_uuid, same as docker-compose broker CLUSTER_ID)"
  value       = random_uuid.kraft_cluster.result
}

output "connect_cluster_id" {
  description = "Kafka Connect cluster ID (from SSM after instance bootstrap, when fetch_connect_cluster_id is true)"
  value       = var.connect_cluster_id
}

output "cc_sr_context_prefix" {
  description = "Context prefix for Confluent Cloud Schema Registry (not sensitive; derived via nonsensitive from cc_sr)"
  value       = nonsensitive(var.cc_sr.context_prefix)
}
