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
cp -f "${REPO_DIR}/application_code/nginx.conf" /tmp/nginx.conf
sed -i "s|__APP_ALB_DNS__|${APP_ALB_DNS}|g" /tmp/nginx.conf
install -o root -g root -m 0644 /tmp/nginx.conf /etc/nginx/nginx.conf

log "Building frontend"
/home/ec2-user/web.sh

log "Validating and starting nginx"
nginx -t
systemctl enable --now nginx
systemctl restart nginx

log "Web tier setup completed"
