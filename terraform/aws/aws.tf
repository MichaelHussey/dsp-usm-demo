data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ------------------------------------------------------------------------------
# Secrets Manager: store SSH private key for bastion to fetch at boot
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "bastion_ssh_key" {
  name                    = "${var.cluster_name}/bastion-ssh-key-${module.keypair.key_pair_id}"
  description             = "SSH private key for bastion host to access private EC2 instance"
  recovery_window_in_days = 0

  tags = {
    Name        = "${var.cluster_name}-bastion-ssh-key"
    owner_email = var.owner_email
  }
}

resource "aws_secretsmanager_secret_version" "bastion_ssh_key" {
  secret_id     = aws_secretsmanager_secret.bastion_ssh_key.id
  secret_string = module.keypair.private_key_pem
}

# IAM role for bastion: read the SSH key from Secrets Manager
resource "aws_iam_role" "bastion" {
  name = "${var.cluster_name}-bastion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.cluster_name}-bastion-role"
    owner_email = var.owner_email
  }
}

resource "aws_iam_role_policy" "bastion_secrets" {
  name = "${var.cluster_name}-bastion-secrets"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [aws_secretsmanager_secret.bastion_ssh_key.arn]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.cluster_name}-bastion-profile"
  role = aws_iam_role.bastion.name

  tags = {
    Name        = "${var.cluster_name}-bastion-profile"
    owner_email = var.owner_email
  }
}

# Bastion host (public subnet, public IP) for SSH access to private EC2
# Fetches the SSH key from Secrets Manager at boot and installs it under ~/.ssh/
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = module.keypair.key_name
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/bastion_user_data.sh", {
    key_name    = module.keypair.key_name
    secret_name = aws_secretsmanager_secret.bastion_ssh_key.name
    aws_region  = var.region
    KEY_DIR     = "/home/ec2-user/.ssh"
  })

  tags = {
    Name = "${var.cluster_name}-bastion"
  }
}

# ------------------------------------------------------------------------------
# CPCluster node EC2 instances (private subnet, runs Confluent Platform)
# ------------------------------------------------------------------------------
module "cp_node" {
  source = "./modules/cp_node"
  count  = var.cp_node_count

  cluster_name          = "USM Demo cluster no ${count.index + 1}"
  instance_index        = count.index
  subnet_id             = aws_subnet.private[count.index % length(aws_subnet.private)].id
  security_group_ids    = [aws_security_group.ec2.id]
  key_name           = module.keypair.key_name
  bootstrap_endpoint = one([for e in confluent_kafka_cluster.enterprise.endpoints : e if e.access_point_id == confluent_access_point.ingress.id]).bootstrap_endpoint
  api_key               = confluent_api_key.cluster_admin_key.id
  api_secret            = confluent_api_key.cluster_admin_key.secret
  usm_api_key           = confluent_api_key.cp_usm_key.id
  usm_api_secret        = confluent_api_key.cp_usm_key.secret
  broker_image          = "confluentinc/cp-server:${var.cp_node_platform_image_tag}"
  connect_image         = "confluentinc/cp-server-connect:${var.cp_node_platform_image_tag}"
  schema_registry_image = "confluentinc/cp-schema-registry:${var.cp_node_platform_image_tag}"
  aws_region            = var.region
  cc_environment_id     = confluent_environment.main.id
  usm_ccloud_endpoint   = aws_route53_record.usm_api.fqdn
}
