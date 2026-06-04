# VPC and networking

# AWS VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.cluster_name}-vpc"
    owner_email = var.owner_email
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.cluster_name}-igw"
    owner_email = var.owner_email
  }
}

# Get available AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets (for NAT Gateway)
resource "aws_subnet" "public" {
  count             = var.availability == "MULTI_ZONE" ? 3 : 1
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.cluster_name}-public-subnet-${count.index + 1}"
    owner_email = var.owner_email
  }
}

# Private Subnets (for PrivateLink endpoints and EC2)
resource "aws_subnet" "private" {
  count             = var.availability == "MULTI_ZONE" ? 3 : 1
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "${var.cluster_name}-private-subnet-${count.index + 1}"
    owner_email = var.owner_email
  }
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.availability == "MULTI_ZONE" ? 3 : 1
  domain = "vpc"

  tags = {
    Name        = "${var.cluster_name}-nat-eip-${count.index + 1}"
    owner_email = var.owner_email
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateways
resource "aws_nat_gateway" "main" {
  count         = var.availability == "MULTI_ZONE" ? 3 : 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.cluster_name}-nat-${count.index + 1}"
    owner_email = var.owner_email
  }

  depends_on = [aws_internet_gateway.main]
}

# Route table for public subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.cluster_name}-public-rt"
    owner_email = var.owner_email
  }
}

# Route table associations for public subnets
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route tables for private subnets
resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.cluster_name}-private-rt-${count.index + 1}"
    owner_email = var.owner_email
  }
}

# Route table associations for private subnets
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

# ------------------------------------------------------------------------------
# Network ACL: explicit allow for bastion <-> cp node (default NACL can block in some configs)
# ------------------------------------------------------------------------------
resource "aws_network_acl" "main" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)

  # Allow all inbound (NACL is stateless; return traffic needs explicit rule)
  ingress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  # Allow all outbound
  egress {
    protocol   = -1
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "${var.cluster_name}-nacl"
    owner_email = var.owner_email
  }
}

# Security Group for EC2 instance
resource "aws_security_group" "ec2" {
  name        = "${var.cluster_name}-ec2-sg"
  description = "Security group for EC2 instance accessing Confluent Cloud via PrivateLink"
  vpc_id      = aws_vpc.main.id

  # Allow outbound HTTPS for Confluent Cloud API and Docker Hub, via the PL endpoints in the VPC
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for Confluent Cloud API and Docker Hub"
  }
  # Allow outbound to PrivateLink endpoints
  egress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kafka broker port via PrivateLink"
  }

  # Allow SSH from bastion (VPC CIDR covers bastion's private IP when connecting within VPC)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH from bastion"
  }
  # Allow Kafka broker port
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kafka broker port"
  }

  # Allow Kafka Connect REST API
  ingress {
    from_port   = 8083
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kafka Connect REST API"
  }

  # Allow Schema Registry REST API
  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Schema Registry REST API"
  }

  # Allow MQTT
  ingress {
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "MQTT broker"
  }

  tags = {
    Name        = "${var.cluster_name}-ec2-sg"
    owner_email = var.owner_email
  }
}

# Security Groups for PrivateLink endpoints
resource "aws_security_group" "privatelink" {
  name        = "${var.cluster_name}-privatelink-sg"
  description = "Security group for PrivateLink endpoint"
  vpc_id      = aws_vpc.main.id

    # Allow Kafka broker and Confluent Cloud API ports
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Kafka broker port"
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS for Confluent Cloud API"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.cluster_name}-privatelink-sg"
    owner_email = var.owner_email
  }
}

# VPC Endpoints for PrivateLink (one per AZ)
# Note: After creation, once these endpoints are accepted by Confluent Cloud, private dns can be enabled
resource "aws_vpc_endpoint" "privatelink" {
  #count               = length(aws_subnet.private)
  vpc_id              = aws_vpc.main.id
  service_name        = confluent_gateway.ingress.aws_ingress_private_link_gateway[0].vpc_endpoint_service_name
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.privatelink.id]
  private_dns_enabled = false

  tags = {
    Name        = "${var.cluster_name}-privatelink-endpoint"
    owner_email = var.owner_email
  }

  depends_on = [
    confluent_gateway.ingress,
    confluent_kafka_cluster.enterprise
  ]
}



# ------------------------------------------------------------------------------
# Bastion host (public IP) for SSH access to private EC2 instance
# ------------------------------------------------------------------------------

# Security group for bastion: SSH from allowed CIDRs only
resource "aws_security_group" "bastion" {
  name        = "${var.cluster_name}-bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_ssh_cidr_blocks
    description = "SSH to bastion"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name        = "${var.cluster_name}-bastion-sg"
    owner_email = var.owner_email
  }
}
