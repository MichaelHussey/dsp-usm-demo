# Connect cluster IDs are assigned at runtime by Kafka Connect on each cp_node.
# user_data writes them to SSM; this data source polls SSM until the value is ready.
# Set fetch_connect_cluster_ids = true to enable (requires AWS CLI during apply).

data "external" "connect_cluster_id" {
  count = var.fetch_connect_cluster_ids ? var.cp_node_count : 0

  program = ["bash", "${path.module}/scripts/get_connect_cluster_id.sh"]

  query = {
    ssm_parameter_name = module.cp_node[count.index].ssm_parameter_name
    aws_region         = var.region
  }

  depends_on = [module.cp_node]
}

locals {
  connect_cluster_ids = var.fetch_connect_cluster_ids ? {
    for i, ext in data.external.connect_cluster_id :
    i => ext.result.connect_cluster_id
  } : {}
}
