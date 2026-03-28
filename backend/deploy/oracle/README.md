# Free Hosting Runbook (Oracle Cloud Always Free)

This is the recommended zero-cost setup for students:
- 1 Oracle VM (Ubuntu)
- Node.js API + MySQL on same VM
- Nginx reverse proxy
- PM2 process manager
- Optional free domain + HTTPS (DuckDNS + Certbot)

## 1) Create free VM
- Oracle Cloud Free Tier
- Image: Ubuntu 22.04
- Shape: Always Free eligible
- Open ports in Oracle security list: `22`, `80`, `443`

## 2) Connect to VM
```bash
ssh ubuntu@<YOUR_VM_PUBLIC_IP>
```

## 3) Setup server packages
```bash
chmod +x /var/www/medical-suivi/project/backend/deploy/oracle/setup-server.sh
# If project not cloned yet, clone first to any directory and run setup script from there
./backend/deploy/oracle/setup-server.sh
```

## 4) Create MySQL DB/user
```bash
sudo mysql
CREATE DATABASE IF NOT EXISTS medical_suivi;
CREATE USER IF NOT EXISTS 'medical_app'@'localhost' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON medical_suivi.* TO 'medical_app'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

## 5) Deploy app
```bash
chmod +x backend/deploy/oracle/deploy-app.sh
./backend/deploy/oracle/deploy-app.sh <YOUR_GITHUB_REPO_URL> <YOUR_DOMAIN> main
```

Example:
```bash
./backend/deploy/oracle/deploy-app.sh https://github.com/you/medical-suivi.git api-medigo.duckdns.org main
```

## 6) Add backend .env on server
Create:
```bash
/var/www/medical-suivi/project/backend/.env
```
Use template from:
```bash
backend/deploy/oracle/.env.production.example
```

## 7) Run migration / schema once
```bash
cd /var/www/medical-suivi/project/backend
npm run migrate
```

## 8) HTTPS (free)
```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d <YOUR_DOMAIN>
```

## 9) Verify API
```bash
curl https://<YOUR_DOMAIN>/
curl https://<YOUR_DOMAIN>/api/notifications -H "Authorization: Bearer <TOKEN>"
```

## 10) Point mobile app to hosted backend
Use:
```bash
flutter run --dart-define=API_BASE_URL=https://<YOUR_DOMAIN>/api
```

For release build, keep same value in your CI/build command.

## Notes
- Free + stable: no sleep (better than many free PaaS).
- Always keep backups for MySQL.
- If app not reachable, check Oracle network security list + Nginx + PM2:
```bash
pm2 status
pm2 logs medical-api --lines 120
sudo systemctl status nginx
```
