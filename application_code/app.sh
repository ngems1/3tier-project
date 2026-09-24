#!/bin/bash
set -euo pipefail

APP_DIR="/home/ec2-user/app_files"
ENV_FILE="/etc/profile.d/app_env.sh"

if [ ! -f "${ENV_FILE}" ]; then
  echo "Missing ${ENV_FILE}; SECRET_NAME and REGION are required" >&2
  exit 1
fi

# Load the same environment used by the application bootstrap. This is
# explicitly sourced because non-interactive/systemd shells do not load
# /etc/profile.d automatically.
source "${ENV_FILE}"
: "${SECRET_NAME:?SECRET_NAME is not set}"
: "${REGION:?REGION is not set}"

chown -R ec2-user:ec2-user /home/ec2-user
chmod -R u=rwX,go=rX "${APP_DIR}"

runuser -u ec2-user -- bash -lc '
  set -euo pipefail
  source /etc/profile.d/app_env.sh
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  cd /home/ec2-user/app_files
  npm install --no-audit --no-fund
  npm install --no-save --no-audit --no-fund pm2
  pm2 delete three-tier-backend 2>/dev/null || true
  pm2 start index.js --name three-tier-backend --update-env
  pm2 save
'

# Install the PM2 systemd unit for ec2-user when supported by the AMI.
runuser -u ec2-user -- bash -lc 'pm2 startup systemd -u ec2-user --hp /home/ec2-user 2>/dev/null || true'
