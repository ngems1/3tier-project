#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/ngems1/3tier-project.git"
REPO_DIR="/home/ec2-user/3tier-project"

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

log "Updating system and installing web dependencies"
dnf update -y
dnf install -y nginx git

log "Checking out application repository"
if [ -d "${REPO_DIR}/.git" ]; then
  git -C "${REPO_DIR}" fetch --depth 1 origin main
  git -C "${REPO_DIR}" reset --hard origin/main
else
  rm -rf "${REPO_DIR}"
  git clone --depth 1 --branch main "${REPO_URL}" "${REPO_DIR}"
fi

log "Copying frontend build script"
install -o ec2-user -g ec2-user -m 0755 \
  "${REPO_DIR}/application_code/web.sh" \
  /home/ec2-user/web.sh

log "Preparing nginx configuration"
# Terraform replaces __APP_ALB_DNS__ with the internal ALB DNS name before
# this user-data script is passed to the launch template.
install -o root -g root -m 0644 \
  "${REPO_DIR}/application_code/nginx.conf" \
  /etc/nginx/nginx.conf

log "Building frontend"
/home/ec2-user/web.sh

log "Validating and starting nginx"
nginx -t
systemctl enable --now nginx
systemctl restart nginx

log "Web tier setup completed"
