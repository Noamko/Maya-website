# Deployment Guide for Digital Ocean

## Prerequisites

1. Digital Ocean Droplet (Ubuntu 20.04 or later recommended)
2. Node.js 16+ installed
3. PM2 for process management
4. Nginx as reverse proxy
5. SSL certificate (Let's Encrypt recommended)

## Step-by-Step Deployment

### 1. Prepare Your Server

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Node.js 18.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# Install PM2 globally
sudo npm install -g pm2

# Install Nginx
sudo apt install -y nginx

# Install Certbot for SSL
sudo apt install -y certbot python3-certbot-nginx
```

### 2. Upload Your Application

```bash
# On your server, create app directory
mkdir -p /var/www/maya-website
cd /var/www/maya-website

# Clone or upload your files
# Option 1: Using git
git clone <your-repo-url> .

# Option 2: Using SCP from your local machine
# scp -r /Users/noamk/projects/Maya-website/* root@your-server-ip:/var/www/maya-website/
```

### 3. Configure Environment Variables

```bash
# Create .env file
nano .env
```

Add the following content (customize for your domain):

```env
NODE_ENV=production
PORT=3000
SESSION_SECRET=<generate-random-string>
DOMAIN_URL=https://yourdomain.com
FRONTEND_URL=https://yourdomain.com
```

To generate a secure session secret:
```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

### 4. Install Dependencies

```bash
npm install --production
```

### 5. Configure PM2

Create `ecosystem.config.js`:

```bash
nano ecosystem.config.js
```

Add:

```javascript
module.exports = {
  apps: [{
    name: 'maya-website',
    script: './server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
```

Start the application:

```bash
# Start with PM2
pm2 start ecosystem.config.js

# Save PM2 configuration
pm2 save

# Setup PM2 to start on boot
pm2 startup
# Follow the command it outputs
```

### 6. Configure Nginx

```bash
sudo nano /etc/nginx/sites-available/maya-website
```

Add the following configuration:

```nginx
server {
    listen 80;
    server_name yourdomain.com www.yourdomain.com;

    # Redirect to HTTPS (will be enabled after SSL setup)
    # return 301 https://$server_name$request_uri;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # Serve static files directly
    location /assets/ {
        proxy_pass http://localhost:3000/assets/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

Enable the site:

```bash
sudo ln -s /etc/nginx/sites-available/maya-website /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Setup SSL with Let's Encrypt

```bash
# Get SSL certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Certbot will automatically configure Nginx for HTTPS
# It will also set up auto-renewal
```

### 8. Configure Firewall

```bash
# Allow HTTP and HTTPS
sudo ufw allow 'Nginx Full'
sudo ufw allow OpenSSH
sudo ufw enable
```

### 9. Test Your Deployment

```bash
# Check if app is running
pm2 status

# View logs
pm2 logs maya-website

# Check Nginx status
sudo systemctl status nginx

# Test the website
curl http://localhost:3000
curl https://yourdomain.com
```

## Important Security Notes

1. **Change Default Admin Password**: After first login, create a new admin user or change the default password
2. **Session Secret**: Use a strong, random session secret in production
3. **Database Backup**: Regularly backup your `blog.db` file
4. **File Permissions**: Ensure proper permissions on uploads directory

```bash
chmod 755 /var/www/maya-website
chmod 644 /var/www/maya-website/blog.db
chmod 755 /var/www/maya-website/assets/uploads
```

## Maintenance Commands

```bash
# Restart application
pm2 restart maya-website

# View logs
pm2 logs maya-website

# Monitor application
pm2 monit

# Update application
cd /var/www/maya-website
git pull
npm install --production
pm2 restart maya-website

# Backup database
cp blog.db blog.db.backup-$(date +%Y%m%d)
```

## Troubleshooting

### Issue: 502 Bad Gateway
- Check if Node.js app is running: `pm2 status`
- Check logs: `pm2 logs maya-website`
- Restart app: `pm2 restart maya-website`

### Issue: Authentication not working
- Ensure `trust proxy` is enabled in server.js (already done)
- Check if `secure` cookie is set to true in production
- Verify HTTPS is working

### Issue: CORS errors
- Make sure DOMAIN_URL and FRONTEND_URL in .env match your actual domain
- Check Nginx is properly forwarding headers

### Issue: Uploads not working
- Check uploads directory permissions: `ls -la /var/www/maya-website/assets/uploads`
- Ensure directory exists and is writable

## Performance Optimization

1. **Enable compression in Nginx**:
```nginx
gzip on;
gzip_vary on;
gzip_min_length 1000;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
```

2. **Add to Nginx config for better caching**:
```nginx
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|webp)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

3. **Monitor with PM2**:
```bash
pm2 install pm2-logrotate
```

## Backup Strategy

Create a backup script at `/var/www/maya-website/backup.sh`:

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/maya-website"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup database
cp /var/www/maya-website/blog.db "$BACKUP_DIR/blog-$DATE.db"

# Backup uploads
tar -czf "$BACKUP_DIR/uploads-$DATE.tar.gz" /var/www/maya-website/assets/uploads/

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.db" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

Make it executable and add to crontab:
```bash
chmod +x /var/www/maya-website/backup.sh
crontab -e
# Add: 0 2 * * * /var/www/maya-website/backup.sh
```

