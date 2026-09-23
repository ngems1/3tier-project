#!/bin/bash
set -euo pipefail

REPO_URL="https://github.com/ngems1/3tier-project.git"
REPO_DIR="/home/ec2-user/3tier-project"
APP_DIR="${REPO_DIR}/application_code/app_files"

log() {
  echo "[$(date --iso-8601=seconds)] $*"
}

log "Updating system and installing app dependencies"
dnf update -y
dnf install -y git jq mysql

# The backend AMI normally provides Node.js and PM2. Install the packages here
# as a fallback so a fresh AMI can still start the application.
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  dnf install -y nodejs npm
fi

log "Checking out application repository"
if [ -d "${REPO_DIR}/.git" ]; then
  git -C "${REPO_DIR}" fetch --depth 1 origin main
  git -C "${REPO_DIR}" reset --hard origin/main
else
  rm -rf "${REPO_DIR}"
  git clone --depth 1 --branch main "${REPO_URL}" "${REPO_DIR}"
fi

log "Configuring application environment"
cat > /etc/profile.d/app_env.sh <<EOF
export SECRET_NAME="${secret_name}"
export REGION="${region}"
export ENVIRONMENT="${environment}"
export PROJECT_NAME="${project_name}"
EOF
chmod 0644 /etc/profile.d/app_env.sh

log "Installing backend application"
rm -rf /home/ec2-user/app_files
cp -R "${APP_DIR}" /home/ec2-user/app_files
install -o ec2-user -g ec2-user -m 0755 \
  "${REPO_DIR}/application_code/app.sh" \
  /home/ec2-user/app.sh
chown -R ec2-user:ec2-user /home/ec2-user/app_files
chmod -R u=rwX,go=rX /home/ec2-user/app_files

log "Starting backend application"
/home/ec2-user/app.sh

log "App tier setup completed"
