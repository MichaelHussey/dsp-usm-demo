data "aws_caller_identity" "current" {}

locals {
  ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com"
  ecr_images = {
    broker          = "${local.ecr_registry}/${aws_ecr_repository.cp_server.name}:${var.cp_node_platform_image_tag}"
    connect         = "${local.ecr_registry}/${aws_ecr_repository.cp_connect.name}:latest"
    schema_registry = "${local.ecr_registry}/${aws_ecr_repository.cp_schema_registry.name}:${var.cp_node_platform_image_tag}"
    usm_agent       = "${local.ecr_registry}/${aws_ecr_repository.cp_usm_agent.name}:${var.cp_node_platform_image_tag}"
    mosquitto       = "${local.ecr_registry}/${aws_ecr_repository.mosquitto.name}:2"
  }
}

resource "aws_ecr_repository" "cp_server" {
  name                 = "${var.prefix}/cp-server"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "cp_connect" {
  name                 = "${var.prefix}/cp-connect_withplugins"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "cp_schema_registry" {
  name                 = "${var.prefix}/cp-schema-registry"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "cp_usm_agent" {
  name                 = "${var.prefix}/cp-usm-agent"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "mosquitto" {
  name                 = "${var.prefix}/mosquitto"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
