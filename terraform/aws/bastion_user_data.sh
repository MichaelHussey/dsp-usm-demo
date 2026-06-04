#!/bin/bash
# Fetch the SSH private key from Secrets Manager and install on the bastion
# so we can SSH from bastion to the private EC2 instance.
set -e
command -v aws >/dev/null 2>&1 || dnf install -y aws-cli
KEY_DIR="/home/ec2-user/.ssh"
KEY_FILE="${KEY_DIR}/${key_name}.pem"
mkdir -p "$KEY_DIR"
aws secretsmanager get-secret-value \
  --region "${aws_region}" \
  --secret-id "${secret_name}" \
  --query SecretString \
  --output text > "$KEY_FILE"
chmod 600 "$KEY_FILE"
chown -R ec2-user:ec2-user "$KEY_DIR"
echo "SSH key installed successfully"
