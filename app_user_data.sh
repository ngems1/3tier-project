#!/bin/bash
set -euo pipefail

REPOSITORY_URL="${repository_url}"
IMAGE_TAG="latest"

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

get_instance_id() {
  local token
  token=$(curl -fsS -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

  if [ -n "$token" ]; then
    curl -fsS -H "X-aws-ec2-metadata-token: $token" \
      "http://169.254.169.254/latest/meta-data/instance-id" || hostname
  else
    hostname
  fi
}

if [ -z "${secret_name}" ] || [ -z "${region}" ] || [ -z "$REPOSITORY_URL" ]; then
  echo "repository_url, SECRET_NAME, and REGION must be provided by Terraform" >&2
  exit 1
fi

INSTANCE_ID="$(get_instance_id)"
REGISTRY_HOST="$${REPOSITORY_URL%%/*}"
IMAGE_URI="$REPOSITORY_URL:$IMAGE_TAG"

log "Ensuring Docker is enabled"
systemctl enable --now docker

log "Authenticating to Amazon ECR"
aws ecr get-login-password --region "${region}" | \
  docker login --username AWS --password-stdin "$REGISTRY_HOST"

log "Pulling backend image $IMAGE_URI"
docker pull "$IMAGE_URI"

docker rm -f three-tier-backend >/dev/null 2>&1 || true

log "Starting backend container"
docker run -d \
  --name three-tier-backend \
  --restart unless-stopped \
  -p 4000:4000 \
  --env SECRET_NAME="${secret_name}" \
  --env REGION="${region}" \
  --env AWS_REGION="${region}" \
  --env ENVIRONMENT="${environment}" \
  --env PROJECT_NAME="${project_name}" \
  --log-driver=awslogs \
  --log-opt awslogs-region="${region}" \
  --log-opt awslogs-group="/three-tier/${environment}/app" \
  --log-opt awslogs-stream="$INSTANCE_ID/backend" \
  "$IMAGE_URI"

log "Configuring CloudWatch Agent (host metrics only)"
# Container stdout/stderr is shipped with Docker's awslogs driver, so the
# CloudWatch Agent remains responsible for host metrics on the EC2 instance.
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<CWCONFIG
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "namespace": "ThreeTier/${environment}",
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "InstanceId": "$${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": { "measurement": ["used_percent"], "resources": ["/"] }
    }
  }
}
CWCONFIG

if command -v amazon-cloudwatch-agent-ctl >/dev/null 2>&1 || [ -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
else
  log "CloudWatch Agent binary not found; skipping agent start (expected only outside the packer-built AMI)"
fi

log "Backend bootstrap completed"
