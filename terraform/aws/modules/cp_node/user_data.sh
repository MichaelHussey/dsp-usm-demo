#!/bin/bash
set -e
echo "[usm-demo] user-data script started at $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Update system
echo "[usm-demo] running dnf update..."
sudo dnf update -y 

# Install docker - following instructions on https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-docker.html
# Install required packages
sudo dnf install -y docker aws-cli
sudo service docker start
sudo systemctl enable docker

# ec2-user needs supplementary group "docker" to use /var/run/docker.sock without sudo (log out/in or `newgrp docker` after bootstrap)
sudo usermod -aG docker ec2-user

# Docker compose is not available in the repo so we need to install it manually
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Create directory for application and MQTT config
mkdir -p /opt/usm-demo/mosquitto/{config,data,log}
cd /opt/usm-demo


# Create environment file
cat > /opt/usm-demo/.env <<ENVFILE
CC_BOOTSTRAP=${bootstrap_endpoint}
CC_API_KEY=${api_key}
CC_API_SECRET=${api_secret}
AWS_REGION=${aws_region}
BROKER_IMAGE=${broker_image}
CONNECT_IMAGE=${connect_image}
SCHEMA_REGISTRY_IMAGE=${schema_registry_image}
CLUSTER_ID=${cluster_id}
ENVFILE
chmod 600 /opt/usm-demo/.env

# Create Mosquitto MQTT config
cat > /opt/usm-demo/mosquitto/config/mosquitto.conf <<'MQTTCONF'
listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/
log_dest file /mosquitto/log/mosquitto.log
log_type all
MQTTCONF

# Create docker-compose file
cat > /opt/usm-demo/docker-compose.yml <<COMPOSEFILE
services:
  broker:
    image: ${broker_image}
    hostname: broker
    container_name: broker-usm-demo
    ports:
      - "9092:9092"
      - "9101:9101"
      - "8090:8090"
    environment:
      COMPONENT: 'kafka'
      KAFKA_NODE_ID: 1
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: 'CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT'
      KAFKA_ADVERTISED_LISTENERS: 'PLAINTEXT://broker:29092,PLAINTEXT_HOST://localhost:9092'
      KAFKA_DEFAULT_REPLICATION_FACTOR: 1
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_SHARE_COORDINATOR_STATE_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS: 0
      KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_CONFLUENT_BALANCER_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_CONFLUENT_CLUSTER_LINK_METADATA_TOPIC_REPLICATION.FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_CONFLUENT_SCHEMA_REGISTRY_URL: http://schema-registry:8081
      KAFKA_PROCESS_ROLES: 'broker,controller'
      KAFKA_CONTROLLER_QUORUM_VOTERS: '1@broker:29093'
      KAFKA_LISTENERS: 'PLAINTEXT://broker:29092,CONTROLLER://broker:29093,PLAINTEXT_HOST://0.0.0.0:9092'
      KAFKA_INTER_BROKER_LISTENER_NAME: 'PLAINTEXT'
      KAFKA_CONTROLLER_LISTENER_NAMES: 'CONTROLLER'
      CLUSTER_ID: '${cluster_id}'
      KAFKA_CONFLUENT_METADATA_SERVER_LISTENERS: 'http://broker:28090'

      # Disable SBC machinery due to single node deployment
      KAFKA_CONFLUENT_BALANCER_ENABLE: 'false'
      KAFKA_CONFLUENT_REPORTERS_TELEMETRY_AUTO_ENABLE: 'true'

      # USM Agent Telemetry Configuration (Kafka)
      KAFKA_METRIC_REPORTERS: "io.confluent.telemetry.reporter.TelemetryReporter"
      KAFKA_CONFLUENT_TELEMETRY_REMOTECONFIG__CONFLUENT_ENABLED: 'false'
      KAFKA_CONFLUENT_CONSUMER_LAG_EMITTER_ENABLED: 'true'
      KAFKA_CONFLUENT_CONSUMER_LAG_EMITTER_INTERVAL_MS: '10000'
      KAFKA_CONFLUENT_TELEMETRY_EXTERNAL_CLIENT_METRICS_PUSH_ENABLED: 'true'
      KAFKA_CONFLUENT_TELEMETRY_EXTERNAL_CLIENT_METRICS_DELTA_TEMPORALITY: 'false'
      KAFKA_CONFLUENT_TELEMETRY_EXTERNAL_CLIENT_METRICS_SUBSCRIPTION_INTERVAL_MS_LIST: '10000'
      KAFKA_CONFLUENT_TELEMETRY_EXTERNAL_CLIENT_METRICS_SUBSCRIPTION_METRICS_LIST: '*'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_ENABLED: 'true'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_TYPE: 'http'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_CLIENT_BASE_URL: 'http://usm-agent:10000'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_API_KEY: 'dummy'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_API_SECRET: 'dummy'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_EVENTS_ENABLED: 'true'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_EVENTS_CLIENT_BASE_URL: 'http://usm-agent:10000'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_EVENTS_API_KEY: 'dummy'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_EVENTS_API_SECRET: 'dummy'
      KAFKA_CONFLUENT_CATALOG_COLLECTOR_ENABLE: 'true'
      KAFKA_CONFLUENT_CATALOG_COLLECTOR_DESTINATION_TOPIC: 'catalog-events'
      KAFKA_CONFLUENT_CATALOG_COLLECTOR_FULL_CONFIGS_ENABLE: 'true'
      KAFKA_CONFLUENT_CATALOG_COLLECTOR_MULTITENANT_TOPICS_ENABLE: 'false'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_EVENTS_FILTERING_ENABLED: 'true'
      KAFKA_CONFLUENT_TELEMETRY_EXPORTER_\_USM_EVENTS_FILTERING_ROUTES_ALLOWED: 'catalog-events'
      KAFKA_CONFLUENT_CLIENT_TOPIC_METRICS_MANAGER: 'org.apache.kafka.server.metrics.PlatformClientTopicMetricsManager'
    restart: unless-stopped

  connect:
    image: ${connect_image}
    hostname: connect
    container_name: connect-usm-demo
    depends_on:
      - broker
    ports:
      - "8083:8083"
    environment:
      CONNECT_BOOTSTRAP_SERVERS: 'broker:29092'
      CONNECT_REST_ADVERTISED_HOST_NAME: connect
      CONNECT_GROUP_ID: compose-connect-group
      CONNECT_CONFIG_STORAGE_TOPIC: docker-connect-configs
      CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_OFFSET_FLUSH_INTERVAL_MS: 10000
      CONNECT_OFFSET_STORAGE_TOPIC: docker-connect-offsets
      CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_STATUS_STORAGE_TOPIC: docker-connect-status
      CONNECT_STATUS_STORAGE_REPLICATION_FACTOR: 1
      CONNECT_KEY_CONVERTER: org.apache.kafka.connect.storage.StringConverter
      CONNECT_VALUE_CONVERTER: io.confluent.connect.avro.AvroConverter
      CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL: http://schema-registry:8081
      CONNECT_PLUGIN_DISCOVERY: "SERVICE_LOAD"
      CONNECT_PLUGIN_PATH: "/usr/share/java,/usr/share/confluent-hub-components"
      KAFKA_OPTS: "-Djava.io.tmpdir=/tmp/connect-tmp"
      CONNECT_CONNECTOR_CLIENT_CONFIG_OVERRIDE_POLICY: "All"

      # USM Agent Telemetry Configuration (Connect)
      CONNECT_METRIC_REPORTERS: "io.confluent.telemetry.reporter.TelemetryReporter"
      CONNECT_TELEMETRY_EXPORTER_\_USM_ENABLED: 'true'
      CONNECT_TELEMETRY_EXPORTER_\_USM_TYPE: 'http'
      CONNECT_TELEMETRY_EXPORTER_\_USM_CLIENT_BASE_URL: 'http://usm-agent:10000'
      CONNECT_TELEMETRY_EXPORTER_\_USM_API_KEY: 'dummy'
      CONNECT_TELEMETRY_EXPORTER_\_USM_API_SECRET: 'dummy'
      CONNECT_TELEMETRY_EXPORTER_\_USM_EVENTS_ENABLED: 'true'
      CONNECT_TELEMETRY_EXPORTER_\_USM_EVENTS_CLIENT_BASE_URL: 'http://usm-agent:10000'
      CONNECT_TELEMETRY_EXPORTER_\_USM_EVENTS_API_KEY: 'dummy'
      CONNECT_TELEMETRY_EXPORTER_\_USM_EVENTS_API_SECRET: 'dummy'
    restart: unless-stopped

  schema-registry-native:
    image: ${schema_registry_image}
    hostname: schema-registry
    container_name: schema-registry
    depends_on:
      - broker
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: 'broker:29092'
      SCHEMA_REGISTRY_LISTENERS: http://0.0.0.0:8081
    restart: unless-stopped

  usm-agent:
    image: ${usm_agent_image}
    hostname: usm-agent
    container_name: usm-agent
    depends_on:
      - broker
    ports:
      - "10000:10000"
    volumes:
      - /opt/usm-demo/usm-agent.properties:/etc/confluent/usm-agent/usm-agent.properties
      - /opt/usm-demo/ccloud_credential.yaml:/etc/confluent/usm-agent/secrets/ccloud_credential.yaml
    command:
      - -l
      - debug
    restart: unless-stopped

  mqtt:
    image: ${mqtt_image}
    hostname: mqtt
    container_name: mqtt
    ports:
      - "1883:1883"
    volumes:
      - /opt/usm-demo/mosquitto/data:/mosquitto/data
      - /opt/usm-demo/mosquitto/log:/mosquitto/log
      - /opt/usm-demo/mosquitto/config:/mosquitto/config
    restart: unless-stopped
COMPOSEFILE

# Create USM agent properties file
# This should only contain the properties that are different from the default properties
echo "Frontdoor URL: ${usm_ccloud_endpoint}"
cat > /opt/usm-demo/usm-agent.properties <<'USMAGENTPROPERTIES'
confluent.usm-agent.ccloud.environment-id=${cc_environment_id}
confluent.usm-agent.ccloud.host=${usm_ccloud_endpoint}
USMAGENTPROPERTIES

# Create ccloud credential file
cat > /opt/usm-demo/ccloud_credential.yaml <<'CCLOUDCREDENTIAL'
resources:
  - "@type": "type.googleapis.com/envoy.extensions.transport_sockets.tls.v3.Secret"
    name: credential
    generic_secret:
      secret:
        # Basic authentication credentials for upstream requests to CCloud.
        # The credential is base64 encoding of username and password joined by a ':'
        inline_string: "Basic ${usm_api_key_secret_b64}"
CCLOUDCREDENTIAL

# Create a script to set up environment variables
cat > /home/ec2-user/setup-confluent.sh <<SCRIPT
export CC_BOOTSTRAP="${bootstrap_endpoint}"
export CC_API_KEY="${api_key}"
export CC_API_SECRET="${api_secret}"
export CLUSTER_ID="${cluster_id}"
export AWS_REGION="${aws_region}"
echo "Confluent Cloud environment variables set!"
echo "Bootstrap: \$CC_BOOTSTRAP"
echo "KRaft CLUSTER_ID (broker): \$CLUSTER_ID"
SCRIPT
chmod +x /home/ec2-user/setup-confluent.sh
chown ec2-user:ec2-user /home/ec2-user/setup-confluent.sh

# Create management scripts
cat > /opt/usm-demo/start.sh <<'STARTSCRIPT'
#!/bin/bash
cd /opt/usm-demo
source .env
docker-compose up -d
echo "usm-demo services started. Use 'docker-compose logs -f' to view logs."
STARTSCRIPT

cat > /opt/usm-demo/stop.sh <<'STOPSCRIPT'
#!/bin/bash
cd /opt/usm-demo
docker-compose down
echo "usm-demo services stopped."
STOPSCRIPT

cat > /opt/usm-demo/restart.sh <<'RESTARTSCRIPT'
#!/bin/bash
cd /opt/usm-demo
docker-compose restart
echo "usm-demo services restarted."
RESTARTSCRIPT

# Connectivity check for USM → Confluent Cloud (TCP, TLS verify, curl)
cat > /opt/usm-demo/test-usm-ccloud-connectivity.sh <<'USMCONNHDR'
#!/bin/bash
set -euo pipefail
USMCONNHDR
cat >> /opt/usm-demo/test-usm-ccloud-connectivity.sh <<INITVARS
USM_HOST='${usm_ccloud_endpoint}'
USM_PORT=443
INITVARS
cat >> /opt/usm-demo/test-usm-ccloud-connectivity.sh <<'USMCONNBODY'
CA_BUNDLE="/etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem"

fail() { echo "ERROR: $*" >&2; exit 1; }

echo "Target: $${USM_HOST}:$${USM_PORT} (USM ccloud.host / ccloud.port from usm-agent.properties)"
echo

echo "=== Layer 1: TCP connectivity ==="
if ! timeout 15 bash -c "exec 3<>/dev/tcp/$${USM_HOST}/$${USM_PORT}"; then
  fail "cannot open TCP socket to $${USM_HOST}:$${USM_PORT}"
fi
echo "TCP: OK"
echo

echo "=== Layer 2: TLS / certificate verification (openssl s_client) ==="
if [[ ! -r "$CA_BUNDLE" ]]; then
  fail "CA bundle not found at $CA_BUNDLE"
fi
SSL_LOG="$(mktemp)"
trap 'rm -f "$SSL_LOG"' EXIT
if ! echo | timeout 25 openssl s_client -connect "$${USM_HOST}:$${USM_PORT}" -servername "$${USM_HOST}" \
  -verify_return_error -CAfile "$CA_BUNDLE" </dev/null >"$SSL_LOG" 2>&1; then
  tail -40 "$SSL_LOG" >&2
  fail "openssl s_client exited non-zero (TLS or verify failure)"
fi
if ! grep -qE 'Verify return code: 0' "$SSL_LOG"; then
  tail -40 "$SSL_LOG" >&2
  fail "certificate verification did not report Verify return code: 0"
fi
echo "TLS: OK (Verify return code: 0)"
echo "(server certificate summary)"
awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' "$SSL_LOG" | \
  openssl x509 -noout -subject -issuer -dates 2>/dev/null || true
echo

echo "=== Layer 3: HTTPS with curl (system CA store, SSL verify) ==="
CURL_HDR="$(mktemp)"
trap 'rm -f "$SSL_LOG" "$CURL_HDR"' EXIT
SSLVR_HTTP="$(
  curl -sS -I --connect-timeout 15 --max-time 40 \
    -D "$CURL_HDR" -o /dev/null -w '%%{ssl_verify_result} %%{http_code}' \
    "https://$${USM_HOST}/"
)" || fail "curl could not complete HTTPS request to https://$${USM_HOST}/"
read -r CURL_SSL_VERIFY CURL_HTTP_CODE <<<"$SSLVR_HTTP"
if [[ "$${CURL_SSL_VERIFY:-1}" != "0" ]]; then
  fail "curl SSL verify result is $${CURL_SSL_VERIFY:-?} (expected 0); see https://curl.se/libcurl/c/libcurl-errors.html"
fi
echo "curl: OK (TLS verify result 0, HTTP $${CURL_HTTP_CODE})"
head -n 15 "$CURL_HDR"
echo

echo "All three layers succeeded."
USMCONNBODY

chmod +x /opt/usm-demo/*.sh
chown -R ec2-user:ec2-user /opt/usm-demo

# Add to .bashrc for convenience
echo "source /home/ec2-user/setup-confluent.sh" >> /home/ec2-user/.bashrc
echo "alias usm-demo-start='cd /opt/usm-demo && ./start.sh'" >> /home/ec2-user/.bashrc
echo "alias usm-demo-stop='cd /opt/usm-demo && ./stop.sh'" >> /home/ec2-user/.bashrc
echo "alias usm-demo-logs='cd /opt/usm-demo && docker-compose logs -f'" >> /home/ec2-user/.bashrc

# Pull Docker images from ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ecr_registry}
echo "Pulling images from ECR..."
docker pull ${broker_image} || echo "Warning: broker image not found in ECR"
docker pull ${connect_image} || echo "Warning: connect image not found in ECR"
docker pull ${schema_registry_image} || echo "Warning: schema-registry image not found in ECR"
docker pull ${usm_agent_image} || echo "Warning: usm-agent image not found in ECR"
docker pull ${mqtt_image} || echo "Warning: mosquitto image not found in ECR"


# Start services (only if images were successfully pulled)
if docker image inspect "${broker_image}" >/dev/null 2>&1 && \
   docker image inspect "${connect_image}" >/dev/null 2>&1 && \
   docker image inspect "${schema_registry_image}" >/dev/null 2>&1 && \
   docker image inspect "${usm_agent_image}" >/dev/null 2>&1 && \
   docker image inspect "${mqtt_image}" >/dev/null 2>&1; then
  echo "All images found, starting services..."
  cd /opt/usm-demo
  source .env
  docker-compose up -d
  echo "USM-demo services started successfully!"
else
  echo "Warning: Some images are missing in ECR. Run terraform apply with sync_images_to_ecr = true, then run:"
  echo "  cd /opt/usm-demo && ./start.sh"
fi

# Idempotent: ensure ec2-user is in docker group after dnf/docker activity in this script
sudo usermod -aG docker ec2-user

# Deploy some DataGen 
cat >> /opt/usm-demo/deploy-sample-data.sh <<'DEPLOYSAMPLEDATABODY'
docker-compose exec connect curl -X POST -H "Content-Type: application/json" --data '{"name": "datagen-source", "config": {"connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector", "kafka.topic": "orders", "quickstart": "orders", "max.interval": 1000, "iterations": 1000000, "tasks.max": "1"}}' http://connect:8083/connectors
DEPLOYSAMPLEDATABODY

chmod +x /opt/usm-demo/deploy-sample-data.sh
chown -R ec2-user:ec2-user /opt/usm-demo

# Wait for the Connect worker to be ready 
echo "Waiting for the Connect worker to be ready..."
while ! docker-compose exec connect curl -s http://connect:8083/connector-plugins | grep -q "DatagenConnector"; do
  echo "Connect worker not ready yet..."
  sleep 10
done
echo "Connect worker is ready!"

# Grab the connect cluster id and persist for Terraform to read via SSM
CONNECT_CLUSTER_ID=$(docker-compose exec connect curl -s http://connect:8083/ | jq -r '.cluster.id')
echo "Connect cluster ID: $CONNECT_CLUSTER_ID"
echo "$CONNECT_CLUSTER_ID" > /opt/usm-demo/connect_cluster_id
chmod 644 /opt/usm-demo/connect_cluster_id
aws ssm put-parameter \
  --region "${aws_region}" \
  --name "${ssm_parameter_name}" \
  --value "$CONNECT_CLUSTER_ID" \
  --type String \
  --overwrite

# Deploy the sample data
/opt/usm-demo/deploy-sample-data.sh
