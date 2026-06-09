#!/bin/bash
# External data source: read Connect cluster ID from SSM (written by cp_node user_data).
# Input: JSON on stdin with ssm_parameter_name, aws_region.
# Output: JSON {"connect_cluster_id": "..."} on stdout.
set -euo pipefail

query="$(cat)"
ssm_parameter_name="$(echo "$query" | jq -r '.ssm_parameter_name')"
aws_region="$(echo "$query" | jq -r '.aws_region')"

echo "Waiting for Connect cluster ID in SSM parameter ${ssm_parameter_name}..." >&2
for _ in $(seq 1 60); do
  connect_cluster_id="$(
    aws ssm get-parameter \
      --region "$aws_region" \
      --name "$ssm_parameter_name" \
      --query Parameter.Value \
      --output text 2>/dev/null || true
  )"
  connect_cluster_id="$(echo "$connect_cluster_id" | tr -d '[:space:]')"

  if [[ -n "$connect_cluster_id" && "$connect_cluster_id" != "pending" && "$connect_cluster_id" != "None" ]]; then
    jq -n --arg connect_cluster_id "$connect_cluster_id" '{connect_cluster_id: $connect_cluster_id}'
    exit 0
  fi
  sleep 10
done

echo "Timed out waiting for Connect cluster ID in ${ssm_parameter_name}" >&2
exit 1
