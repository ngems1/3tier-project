#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/ngems1/3tier-project.git"
REPO_DIR="/home/ec2-user/3tier-project"
APP_DIR="$${REPO_DIR}/application_code/app_files"

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

log "Updating system and installing backend dependencies"
dnf update -y
dnf install -y git jq mysql

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  dnf install -y nodejs npm
fi

log "Checking out $${REPO_URL}"
if [ -d "$${REPO_DIR}/.git" ]; then
  git -C "$${REPO_DIR}" fetch --depth 1 origin main
  git -C "$${REPO_DIR}" reset --hard origin/main
else
  rm -rf "$${REPO_DIR}"
  git clone --depth 1 --branch main "$${REPO_URL}" "$${REPO_DIR}"
fi

if [ -z "${secret_name}" ] || [ -z "${region}" ]; then
  echo "SECRET_NAME and REGION must be provided by Terraform" >&2
  exit 1
fi

log "Writing backend runtime environment"
cat > /etc/profile.d/app_env.sh <<EOF
export SECRET_NAME="${secret_name}"
export REGION="${region}"
export AWS_REGION="${region}"
export ENVIRONMENT="${environment}"
export PROJECT_NAME="${project_name}"
EOF
chmod 0644 /etc/profile.d/app_env.sh

log "Installing application files"
rm -rf /home/ec2-user/app_files
cp -R "$${APP_DIR}" /home/ec2-user/app_files
install -o ec2-user -g ec2-user -m 0755 \
  "$${REPO_DIR}/application_code/app.sh" \
  /home/ec2-user/app.sh
chown -R ec2-user:ec2-user /home/ec2-user/app_files
chmod -R u=rwX,go=rX /home/ec2-user/app_files

log "Configuring CloudWatch Agent (metrics + application logs)"
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
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
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/home/ec2-user/.pm2/logs/three-tier-backend-out.log",
            "log_group_name": "/three-tier/${environment}/app",
            "log_stream_name": "{instance_id}/stdout"
          },
          {
            "file_path": "/home/ec2-user/.pm2/logs/three-tier-backend-error.log",
            "log_group_name": "/three-tier/${environment}/app",
            "log_stream_name": "{instance_id}/stderr"
          }
        ]
      }
    }
  }
}
EOF
if command -v amazon-cloudwatch-agent-ctl >/dev/null 2>&1 || [ -x /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl ]; then
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
else
  log "CloudWatch Agent binary not found; skipping agent start (expected only outside the packer-built AMI)"
fi

log "Starting backend"
/home/ec2-user/app.sh
log "Backend bootstrap completed"
