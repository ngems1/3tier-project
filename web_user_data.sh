#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/ngems1/3tier-project.git"
REPO_DIR="/home/ec2-user/3tier-project"
APP_ALB_DNS="__APP_ALB_DNS__"

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

log "Updating system and installing web dependencies"
dnf update -y
dnf install -y nginx git

log "Checking out application repository"
if [ -d "$${REPO_DIR}/.git" ]; then
  git -C "$${REPO_DIR}" fetch --depth 1 origin main
  git -C "$${REPO_DIR}" reset --hard origin/main
else
  rm -rf "$${REPO_DIR}"
  git clone --depth 1 --branch main "$${REPO_URL}" "$${REPO_DIR}"
fi

log "Copying frontend bootstrap scripts"
install -o ec2-user -g ec2-user -m 0755 \
  "$${REPO_DIR}/application_code/web.sh" \
  /home/ec2-user/web.sh

log "Installing nginx configuration"
install -o root -g root -m 0644 \
  "$${REPO_DIR}/application_code/nginx.conf" \
  /etc/nginx/nginx.conf

log "Wiring nginx /api/ proxy to the internal app ALB"
if [ "$${APP_ALB_DNS}" = "__APP_ALB_DNS__" ]; then
  echo "APP_ALB_DNS placeholder was not substituted by Terraform" >&2
  exit 1
fi
sed -i "s#__APP_ALB_DNS__#$${APP_ALB_DNS}#g" /etc/nginx/nginx.conf

log "Building frontend"
/home/ec2-user/web.sh

log "Validating and starting nginx"
nginx -t
systemctl enable --now nginx
systemctl restart nginx

log "Configuring CloudWatch Agent (metrics + nginx logs)"
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
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/three-tier/${environment}/web",
            "log_stream_name": "{instance_id}/access"
          },
          {
            "file_path": "/var/log/nginx/error.log",
            "log_group_name": "/three-tier/${environment}/web",
            "log_stream_name": "{instance_id}/error"
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

log "Web tier setup completed"
