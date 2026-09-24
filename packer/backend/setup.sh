#!/bin/bash
set -e

echo '📦 Updating system and installing Docker'
sudo dnf update -y
sudo dnf install -y docker amazon-cloudwatch-agent

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

echo '📦 Verifying installations'
docker --version
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -help >/dev/null

echo '✅ Backend Docker AMI preparation complete!'
