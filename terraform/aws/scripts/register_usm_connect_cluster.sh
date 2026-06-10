#!/bin/bash
set -euo pipefail

: "${CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID:?CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID is required}"
: "${CONFLUENT_PLATFORM_CONNECT_CLUSTER_ID:?CONFLUENT_PLATFORM_CONNECT_CLUSTER_ID is required}"
: "${CLOUD:?CLOUD is required}"
: "${REGION:?REGION is required}"
: "${ENVIRONMENT_ID:?ENVIRONMENT_ID is required}"
: "${USM_API_KEY:?USM_API_KEY is required}"
: "${USM_API_SECRET:?USM_API_SECRET is required}"

AUTH="$(printf '%s' "${USM_API_KEY}:${USM_API_SECRET}" | base64 | tr -d '\n')"

payload="$(jq -n \
  --arg confluent_platform_connect_cluster_id "$CONFLUENT_PLATFORM_CONNECT_CLUSTER_ID" \
  --arg kafka_cluster_id "$CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID" \
  --arg cloud "$CLOUD" \
  --arg region "$REGION" \
  --arg env_id "$ENVIRONMENT_ID" \
  '{
    confluent_platform_connect_cluster_id: $confluent_platform_connect_cluster_id,
    kafka_cluster_id: $kafka_cluster_id,
    cloud: $cloud,
    region: $region,
    environment: { id: $env_id }
  }')"

echo "Registering USM agent for Confluent Platform Connect cluster ${CONFLUENT_PLATFORM_CONNECT_CLUSTER_ID}..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${AUTH}" \
  --url https://confluent.cloud/api/usm/v1/connect-clusters  \
  -d "$payload" | jq .

echo "USM agent registered to Confluent Cloud."
