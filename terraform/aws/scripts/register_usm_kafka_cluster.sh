#!/bin/bash
set -euo pipefail

: "${DISPLAY_NAME:?DISPLAY_NAME is required}"
: "${CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID:?CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID is required}"
: "${CLOUD:?CLOUD is required}"
: "${REGION:?REGION is required}"
: "${ENVIRONMENT_ID:?ENVIRONMENT_ID is required}"
: "${USM_API_KEY:?USM_API_KEY is required}"
: "${USM_API_SECRET:?USM_API_SECRET is required}"

AUTH="$(printf '%s' "${USM_API_KEY}:${USM_API_SECRET}" | base64 | tr -d '\n')"

payload="$(jq -n \
  --arg display_name "$DISPLAY_NAME" \
  --arg cluster_id "$CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID" \
  --arg cloud "$CLOUD" \
  --arg region "$REGION" \
  --arg env_id "$ENVIRONMENT_ID" \
  '{
    display_name: $display_name,
    confluent_platform_kafka_cluster_id: $cluster_id,
    cloud: $cloud,
    region: $region,
    environment: { id: $env_id }
  }')"

echo "Registering USM agent for Confluent Platform cluster ${CONFLUENT_PLATFORM_KAFKA_CLUSTER_ID}..."
curl -s -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Basic ${AUTH}" \
  --url https://confluent.cloud/api/usm/v1/kafka-clusters  \
  -d "$payload" | jq .

echo "USM agent registered to Confluent Cloud."
