#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/www/medical-suivi"
API_DIR="$APP_DIR/backend"

echo "[1/7] System update"
sudo apt-get update -y
sudo apt-get upgrade -y

echo "[2/7] Install base packages"
sudo apt-get install -y curl git nginx mysql-server

echo "[3/7] Install Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs

echo "[4/7] Install PM2"
sudo npm install -g pm2

echo "[5/7] Prepare app directory"
sudo mkdir -p "$APP_DIR"
sudo chown -R "$USER":"$USER" "$APP_DIR"

echo "[6/7] Enable services"
sudo systemctl enable nginx
sudo systemctl enable mysql
sudo systemctl start nginx
sudo systemctl start mysql

echo "[7/7] Open firewall (if UFW active)"
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow OpenSSH || true
  sudo ufw allow 'Nginx Full' || true
fi

echo "Done. Next: run deploy-app.sh with your repo + domain."
