#!/bin/bash
# Build the Connect image with plugins locally and push to ECR.
set -euo pipefail

: "${AWS_REGION:?AWS_REGION is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${ECR_REPO_CONNECT:?ECR_REPO_CONNECT is required}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="${SCRIPT_DIR}/../docker"
DOCKER_PLATFORM="${DOCKER_PLATFORM:-linux/amd64}"
CONNECT_TAG="${CONNECT_TAG:-latest}"

ecr_login() {
  aws ecr get-login-password --region "$AWS_REGION" | \
    docker login --username AWS --password-stdin "$ECR_REGISTRY"
}

resolve_connect_base_image() {
  local candidate="confluentinc/cp-server-connect-base:${IMAGE_TAG}-ubi8"
  if docker manifest inspect "$candidate" >/dev/null 2>&1; then
    echo "$candidate"
    return
  fi
  echo "Warning: ${candidate} not found; falling back to latest-ubi8 connect base" >&2
  echo "confluentinc/cp-server-connect-base:latest-ubi8"
}

verify_image_in_ecr() {
  local repository_name="$1"
  local image_tag="$2"
  aws ecr describe-images \
    --region "$AWS_REGION" \
    --repository-name "$repository_name" \
    --image-ids "imageTag=${image_tag}" \
    >/dev/null
}

echo "Logging in to ECR (${ECR_REGISTRY})..."
ecr_login

CONNECT_BASE="$(resolve_connect_base_image)"
CONNECT_TARGET="${ECR_REGISTRY}/${ECR_REPO_CONNECT}:${CONNECT_TAG}"

echo "Building Connect image locally (${DOCKER_PLATFORM})"
echo "  base:   ${CONNECT_BASE}"
echo "  target: ${CONNECT_TARGET}"

docker build \
  --platform "$DOCKER_PLATFORM" \
  --pull \
  --build-arg "CONNECT_BASE_IMAGE=${CONNECT_BASE}" \
  -f "${DOCKER_DIR}/Dockerfile-connect-install" \
  -t "$CONNECT_TARGET" \
  "$DOCKER_DIR"

docker push "$CONNECT_TARGET"

echo "Verifying ${ECR_REPO_CONNECT}:${CONNECT_TAG} exists in ECR..."
verify_image_in_ecr "$ECR_REPO_CONNECT" "$CONNECT_TAG"

echo "Connect image available at ${CONNECT_TARGET}"
