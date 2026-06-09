resource "aws_ssm_parameter" "connect_cluster_id" {
  name  = "/${var.prefix}/cp-node/${var.instance_index}/connect_cluster_id"
  type  = "String"
  value = "pending"
  overwrite = true

  tags = {
    Name = "${var.cluster_name}-connect-cluster-id"
  }

  lifecycle {
    ignore_changes = [value]
  }
}
