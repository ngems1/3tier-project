#!/bin/bash
set -e

echo '📦 Updating system and installing required packages...'
sudo dnf update -y
sudo dnf install -y git

sudo wget https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
sudo dnf install mysql80-community-release-el9-1.noarch.rpm -y
sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
sudo dnf install -y mysql-community-client

echo '📦 Installing NVM (Node Version Manager)'
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

echo '📦 Installing Node.js v22 via NVM'
nvm install 22
npm install -g pm2

echo '📦 Installing Amazon CloudWatch Agent'
sudo dnf install -y amazon-cloudwatch-agent

echo '📦 Verifying installations'
node -v
npm -v
pm2 -v
mysql --version
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -help >/dev/null

echo '✅ Backend AMI preparation complete!'
