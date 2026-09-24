#!/bin/bash
set -e

echo '📦 Updating system packages'
sudo dnf update -y

echo '📦 Installing nginx and git'
sudo dnf install -y nginx git

sudo systemctl enable nginx
sudo systemctl start nginx

echo '📦 Installing NVM (Node Version Manager)'
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

echo '📦 Installing Node.js v22 via NVM'
nvm install 22

echo '📦 Verifying Node.js installation'
node -v
npm -v

echo '📦 Installing Amazon CloudWatch Agent'
sudo dnf install -y amazon-cloudwatch-agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -help >/dev/null

echo '✅ Frontend AMI preparation complete!'
