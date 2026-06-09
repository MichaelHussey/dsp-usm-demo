# ===============================
# CP Node EC2 Instance Module
# ===============================
# EC2 instance in private subnet running native CP components (broker, connect, schema-registry)

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "random_uuid" "kraft_cluster" {}

resource "aws_instance" "cp_node" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "m5.large"                   # minimum type for native is t3.small
  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids
  key_name                    = var.key_name
  user_data_replace_on_change = true
  root_block_device {
    volume_size = 30 # GB
  }
  user_data_base64 = base64gzip(templatefile("${path.module}/user_data.sh", {
    bootstrap_endpoint       = var.bootstrap_endpoint
    api_key                  = var.api_key
    api_secret               = var.api_secret
    api_key_secret_b64       = base64encode("${var.api_key}:${var.api_secret}")
    usm_api_key_secret_b64   = base64encode("${var.usm_api_key}:${var.usm_api_secret}")
    cc_environment_id        = var.cc_environment_id
    usm_ccloud_endpoint      = var.usm_ccloud_endpoint
    broker_image             = var.broker_image
    connect_image            = var.connect_image
    schema_registry_image    = var.schema_registry_image
    aws_region               = var.aws_region
    cluster_id               = random_uuid.kraft_cluster.result
  }))

  tags = {
    Name       = "${var.cluster_name}-cp-node-${var.instance_index}"
    cluster_id = random_uuid.kraft_cluster.result
  }
}


