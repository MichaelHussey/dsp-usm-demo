# Mirror Docker Hub images and build/push the Connect image to ECR.
# Set sync_images_to_ecr = true (requires Docker and AWS CLI on the machine running Terraform).

locals {
  ecr_sync_env = {
    AWS_REGION               = var.region
    IMAGE_TAG                = var.cp_node_platform_image_tag
    ECR_REGISTRY             = local.ecr_registry
    ECR_REPO_SERVER          = aws_ecr_repository.cp_server.name
    ECR_REPO_CONNECT         = aws_ecr_repository.cp_connect.name
    ECR_REPO_SCHEMA_REGISTRY = aws_ecr_repository.cp_schema_registry.name
    ECR_REPO_USM_AGENT       = aws_ecr_repository.cp_usm_agent.name
    ECR_REPO_MOSQUITTO       = aws_ecr_repository.mosquitto.name
    CONNECT_TAG              = "latest"
    DOCKER_PLATFORM          = "linux/amd64"
    DOCKER_BUILD_NO_CACHE    = tostring(var.connect_image_force_rebuild)
  }
}

resource "terraform_data" "sync_ecr_hub_images" {
  count = var.sync_images_to_ecr ? 1 : 0

  triggers_replace = [
    var.cp_node_platform_image_tag,
    aws_ecr_repository.cp_server.repository_url,
    aws_ecr_repository.cp_schema_registry.repository_url,
    aws_ecr_repository.cp_usm_agent.repository_url,
    aws_ecr_repository.mosquitto.repository_url,
  ]

  depends_on = [
    aws_ecr_repository.cp_server,
    aws_ecr_repository.cp_schema_registry,
    aws_ecr_repository.cp_usm_agent,
    aws_ecr_repository.mosquitto,
  ]

  provisioner "local-exec" {
    command     = "${path.module}/scripts/sync_hub_images_to_ecr.sh"
    environment = local.ecr_sync_env
  }
}

resource "terraform_data" "sync_ecr_connect_image" {
  count = var.sync_images_to_ecr ? 1 : 0

  triggers_replace = [
    var.cp_node_platform_image_tag,
    var.connect_image_rebuild_token,
    var.connect_image_force_rebuild,
    filemd5("${path.module}/docker/Dockerfile-connect-install"),
    aws_ecr_repository.cp_connect.repository_url,
  ]

  depends_on = [
    aws_ecr_repository.cp_connect,
    terraform_data.sync_ecr_hub_images,
  ]

  provisioner "local-exec" {
    command     = "${path.module}/scripts/sync_connect_image_to_ecr.sh"
    environment = local.ecr_sync_env
  }
}
