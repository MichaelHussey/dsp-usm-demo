# Confluent Cloud Enterprise Cluster - Terraform Configuration

This Terraform configuration creates an Enterprise Kafka cluster on Confluent Cloud in AWS.
Then it deploys one or more VMs in a private network with access to the CC cluster.
And it deploys a bastion host to allow ssh access to the VM.

## Prerequisites

1. **Confluent Cloud Account**: You need a Confluent Cloud account with appropriate permissions (Enterprise plan required for PrivateLink)
2. **API Keys**: Create API keys in Confluent Cloud at https://confluent.cloud/settings/api-keys
3. **AWS Account**: An AWS account with permissions to create VPCs, subnets, NAT gateways, VPC endpoints, and EC2 instances
4. **AWS Credentials**: Configure AWS credentials (via `aws configure`, environment variables, or IAM role)
5. **Terraform**: Install Terraform >= 1.0
6. **Terraform Providers**: The Confluent and AWS providers will be automatically downloaded
7. **AWS Key Pair** (optional): An existing EC2 key pair in your AWS account for SSH access to the EC2 instance

## Setup

1. **Copy the example variables file**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars`** with your values:
   - `confluent_cloud_api_key`: Your Confluent Cloud API key
   - `confluent_cloud_api_secret`: Your Confluent Cloud API secret
   - `environment_name`: Name for your Confluent environment
   - `cluster_name`: Name for your Enterprise cluster
   - `region`: AWS region (e.g., `us-east-1`, `eu-west-1`)
   - `availability`: `SINGLE_ZONE` or `MULTI_ZONE`

3. **Initialize Terraform**:
   ```bash
   terraform init
   ```

4. **Review the plan**:
   ```bash
   terraform plan
   ```

5. **Apply the configuration**:
   ```bash
   terraform apply
   ```

## Resources Created

- **Confluent Environment**: A Confluent Cloud environment
- **Inbound PrivateLink Gateway**: Confluent gateway for private connectivity from your VPC to Confluent Cloud
- **Enterprise Kafka Cluster**: A multi-zone Enterprise cluster in AWS connected via PrivateLink
- **Service Account**: A service account for cluster management
- **API Key**: An API key for the service account with cluster admin permissions
- **AWS VPC**: A VPC with public and private subnets across multiple availability zones
- **NAT Gateways**: NAT gateways for outbound internet access from private subnets
- **VPC Endpoints**: Interface endpoints for PrivateLink connectivity to Confluent Cloud
- **EC2 Instance**: A t3.micro instance in a private subnet with Kafka client tools pre-installed

## Outputs

After applying, Terraform will output:
- `cluster_id`: The cluster ID
- `cluster_bootstrap_endpoint`: Bootstrap endpoint for Kafka clients
- `cluster_rest_endpoint`: REST API endpoint
- `bootstrap_servers`: Full bootstrap servers connection string
- `api_key` and `api_secret`: API credentials (sensitive)

## PrivateLink Setup

The configuration creates an inbound PrivateLink gateway in Confluent Cloud and VPC endpoints in AWS. The access point registers your VPC endpoints with the gateway to enable connectivity. If connections are pending, check the Confluent Cloud console:

1. Go to your Confluent Cloud environment
2. Navigate to Networks → Gateways
3. Accept any pending connection requests from your AWS VPC endpoints

## Usage Example

After deployment, you can use the outputs to configure your applications:

```bash
export CC_BOOTSTRAP=$(terraform output -raw bootstrap_servers)
export CC_API_KEY=$(terraform output -raw api_key)
export CC_API_SECRET=$(terraform output -raw api_secret)
```

### Connecting to the EC2 Instance

The EC2 instance is in a private subnet. Use the **bastion host** (public IP) to SSH to it. The bastion fetches the SSH key from **AWS Secrets Manager** at boot and installs it at `~/.ssh/<key_name>.pem`, so you can SSH from the bastion to the private instance without copying the key.

1. **SSH to the bastion** (use the key saved by Terraform; see `terraform output -raw ssh_bastion_command`):

   ```bash
   terraform output -raw ssh_bastion_command
   ```

2. **From the bastion, SSH to the private EC2 instance** (key is already on the bastion):

   ```bash
   terraform output -raw ssh_via_bastion_command
   # Or from the bastion: ssh -i ~/.ssh/<key_name>.pem ec2-user@<private-ip>
   ```

   Or use a single hop from your laptop with SSH proxy (use the same key path as in `ssh_bastion_command`):

   ```bash
   ssh -i path/to/sshkey-*.pem -J ec2-user@$(terraform output -raw bastion_public_ip) ec2-user@$(terraform output -raw ec2_private_ip)
   ```

Restrict `bastion_ssh_cidr_blocks` in production. The EC2 instance has Kafka client tools at `/opt/kafka/bin/` and connects to Confluent Cloud via PrivateLink.

## CP Node Deployment

During `terraform apply`, each CP node Kafka cluster is registered with Confluent Cloud USM via `scripts/register_usm_kafka_cluster.sh` (requires `curl` and `jq`). Connect cluster registration is optional: set `fetch_connect_cluster_ids = true` to poll SSM for Connect IDs and run `scripts/register_usm_connect_cluster.sh` (also requires the AWS CLI; may wait several minutes).

CP node images are stored in ECR so instances pull from your private registry instead of Docker Hub on every deploy. On first use (or when changing `cp_node_platform_image_tag` or `docker/Dockerfile-connect-install`), run `terraform apply` with `sync_images_to_ecr = true` (requires Docker and AWS CLI on the machine running Terraform). Hub images are mirrored from Docker Hub; the Connect image is built locally and pushed to `{prefix}/cp-connect_withplugins:latest`. CP nodes wait for both sync steps before starting.

If `cp-connect_withplugins` is missing in ECR, re-run only the Connect sync:

```bash
terraform apply -replace='terraform_data.sync_ecr_connect_image[0]'
```

To force a fresh Connect build (ignore Docker layer cache), set in `terraform.tfvars`:

```hcl
connect_image_rebuild_token = "2"  # bump any time you need a rebuild
connect_image_force_rebuild = true
sync_images_to_ecr = true
```

Then run `terraform apply`. Set `connect_image_force_rebuild = false` after the rebuild completes.

CP node EC2 instances are configured to:
- Install docker and docker-compose
- Authenticate with ECR and pull images from your ECR repositories
- Deploy the services using docker-compose

If images are not available when the instance starts, SSH to the instance and run:

```bash
# SSH to the instance
terraform output -raw ssh_command

# On the instance, start the services
cd /opt/usm-demo
./start.sh

# View logs
usm-demo-logs
# or
docker-compose logs -f
```

### Managing Services on EC2

The instance includes helper scripts and aliases:

```bash
# Start services
usm-demo-start
# or
cd /opt/usm-demo && ./start.sh

# Stop services
usm-demo-stop
# or
cd /opt/usm-demo && ./stop.sh

# Restart services
cd /opt/usm-demo && ./restart.sh

# View logs
usm-demo-logs
# or
cd /opt/usm-demo && docker-compose logs -f

# Check connectivity to USM Endpoing on Confluent Cloud
/opt/usm-demo/test-usm-ccloud-connectivity.sh
```

### Services Deployed

The following services run on the EC2 instance:

- **broker** (Kafka broker/controller): Ports 9092, 9101, 8090
- **connect-native** (Kafka Connect): Port 8083
- **schema-registry-native** (Schema Registry): Port 8081

All services are configured to use the local broker. To connect to Confluent Cloud, you'll need to configure connectors or clients to use the Confluent Cloud bootstrap endpoint.

## Cost Considerations

**Confluent Cloud:**
- Enterprise clusters on Confluent Cloud are billed based on:
  - Cluster size (CKU - Confluent Kafka Units)
  - Data transfer
  - Storage
  - PrivateLink connectivity (additional charges may apply)

**AWS Resources:**
- NAT Gateways: ~$0.045/hour each + data transfer costs (3 NAT gateways for multi-AZ = ~$97/month base)
- VPC Endpoints: ~$0.01/hour per endpoint + data processing charges (3 endpoints for multi-AZ = ~$22/month base)
- EC2 t3.micro: ~$7.50/month (varies by region)
- Data transfer: Additional charges for data processed through NAT gateways and VPC endpoints

**Cost Optimization Tips:**
- Use SINGLE_ZONE availability to reduce NAT gateway and VPC endpoint costs
- Consider using a single NAT gateway shared across subnets if cost is a concern
- Monitor data transfer costs

Make sure to review both Confluent Cloud and AWS pricing before deploying.

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will delete the cluster and all data. Make sure you have backups if needed.
