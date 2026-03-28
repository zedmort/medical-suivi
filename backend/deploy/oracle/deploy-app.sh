#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <git_repo_url> <domain_or_dash> [branch]"
  echo "Use '-' if you don't have a domain yet (deploy with public IP)."
  echo "Example: $0 https://github.com/you/medical-suivi.git - main"
  echo "Example: $0 https://github.com/you/medical-suivi.git api.medigo.duckdns.org main"
  exit 1
fi

REPO_URL="$1"
DOMAIN="$2"
BRANCH="${3:-main}"
APP_DIR="/var/www/medical-suivi"
PROJECT_DIR="$APP_DIR/project"
BACKEND_DIR="$PROJECT_DIR/backend"

mkdir -p "$APP_DIR"

if [[ ! -d "$PROJECT_DIR/.git" ]]; then
  git clone "$REPO_URL" "$PROJECT_DIR"
fi

cd "$PROJECT_DIR"
git fetch origin
# fallback if branch doesn't exist remotely
if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  git checkout "$BRANCH"
  git pull origin "$BRANCH"
else
  git checkout main || true
  git pull origin main || true
fi

cd "$BACKEND_DIR"
npm ci --omit=dev

if [[ ! -f .env ]]; then
  echo "ERROR: $BACKEND_DIR/.env not found. Create it before starting PM2."
  exit 1
fi

# PM2 process file in repo expects this cwd
cp -f ecosystem.config.cjs /tmp/ecosystem.config.cjs
sed -i "s|/var/www/medical-suivi/backend|$BACKEND_DIR|g" /tmp/ecosystem.config.cjs
pm2 start /tmp/ecosystem.config.cjs --only medical-api || pm2 restart medical-api
pm2 save
pm2 startup systemd -u "$USER" --hp "$HOME" >/tmp/pm2-startup.txt || true

SERVER_NAME="$DOMAIN"
if [[ "$DOMAIN" == "-" ]]; then
  SERVER_NAME="_"
fi

sudo cp -f deploy/oracle/nginx-medigo.conf /etc/nginx/sites-available/medigo
sudo sed -i "s|__DOMAIN__|$SERVER_NAME|g" /etc/nginx/sites-available/medigo
sudo ln -sf /etc/nginx/sites-available/medigo /etc/nginx/sites-enabled/medigo
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx

echo "Deployment done."
if [[ "$DOMAIN" != "-" ]]; then
  echo "Next: configure SSL"
  echo "  sudo apt-get install -y certbot python3-certbot-nginx"
  echo "  sudo certbot --nginx -d $DOMAIN"
else
  echo "Deployed with public IP (no domain)."
  echo "You can add domain + SSL later and rerun deploy-app.sh with your domain."
fi
