#!/bin/bash
# Mirror unmodified images from Docker Hub to ECR.
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${ECR_REPO_SERVER:?ECR_REPO_SERVER is required}"
: "${ECR_REPO_SCHEMA_REGISTRY:?ECR_REPO_SCHEMA_REGISTRY is required}"
: "${ECR_REPO_USM_AGENT:?ECR_REPO_USM_AGENT is required}"
: "${ECR_REPO_MOSQUITTO:?ECR_REPO_MOSQUITTO is required}"

DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"

ecr_login() {
  aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY"
}

pull_from_dockerhub_and_push_to_ecr() {
  local hub_image="$1"
  local ecr_image="$2"
  echo "Pulling unmodified image from Docker Hub: ${hub_image} (${DOCKER_PLATFORM})"
  docker pull --platform "$DOCKER_PLATFORM" "$hub_image"
  docker tag "$hub_image" "$ecr_image"
  echo "Pushing to ECR: ${ecr_image}"
  docker push "$ecr_image"
}

echo "Logging in to ECR (${ECR_REGISTRY})..."
ecr_login

pull_from_dockerhub_and_push_to_ecr \
  "confluentinc/cp-server:${IMAGE_TAG}" \
  "${ECR_REGISTRY}/${ECR_REPO_SERVER}:${IMAGE_TAG}"

pull_from_dockerhub_and_push_to_ecr \
  "confluentinc/cp-schema-registry:${IMAGE_TAG}" \
  "${ECR_REGISTRY}/${ECR_REPO_SCHEMA_REGISTRY}:${IMAGE_TAG}"

pull_from_dockerhub_and_push_to_ecr \
  "confluentinc/cp-usm-agent:latest" \
  "${ECR_REGISTRY}/${ECR_REPO_USM_AGENT}:${IMAGE_TAG}"

pull_from_dockerhub_and_push_to_ecr \
  "eclipse-mosquitto:2" \
  "${ECR_REGISTRY}/${ECR_REPO_MOSQUITTO}:2"

echo "Hub images mirrored to ECR."
