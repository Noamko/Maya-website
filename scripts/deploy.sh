#!/bin/bash
#
# Maya Website - Deployment Script
# Quick deployment for fresh server or updates
#
# Usage:
#   ./scripts/deploy.sh                    # Deploy with self-signed SSL (local/testing)
#   ./scripts/deploy.sh yourdomain.com email@example.com  # Deploy with Let's Encrypt
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

DOMAIN=$1
EMAIL=$2

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose.yml not found. Run this script from the project root."
    exit 1
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    log_error "Docker is not installed. Run ./scripts/setup-server.sh first."
    exit 1
fi

# Check Docker permissions
if ! docker info &> /dev/null; then
    log_error "Cannot connect to Docker. Try: newgrp docker"
    exit 1
fi

echo ""
echo "=============================================="
echo "  Maya Website - Deployment"
echo "=============================================="
echo ""

# Create .env if it doesn't exist
if [ ! -f ".env" ]; then
    log_info "Creating .env file..."
    
    DB_PASSWORD=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 32)
    SESSION_SECRET=$(openssl rand -base64 48)
    
    if [ -n "$DOMAIN" ]; then
        DOMAIN_URL="https://$DOMAIN"
    else
        DOMAIN_URL="https://localhost"
    fi
    
    cat > .env << EOF
POSTGRES_USER=maya_user
POSTGRES_PASSWORD=$DB_PASSWORD
POSTGRES_DB=maya_website
NODE_ENV=production
PORT=3000
SESSION_SECRET=$SESSION_SECRET
DOMAIN_URL=$DOMAIN_URL
FRONTEND_URL=$DOMAIN_URL
EOF
    
    chmod 600 .env
    log_success "Created .env with secure credentials"
fi

# Create necessary directories
mkdir -p certbot/conf certbot/www assets/uploads backups

# Stop existing containers
log_info "Stopping existing containers..."
docker compose down 2>/dev/null || true

# Deploy based on whether domain is provided
if [ -n "$DOMAIN" ] && [ -n "$EMAIL" ]; then
    log_info "Deploying with Let's Encrypt SSL for: $DOMAIN"
    
    # Update .env with domain
    sed -i "s|DOMAIN_URL=.*|DOMAIN_URL=https://$DOMAIN|g" .env
    sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|g" .env
    
    # Check if certificates already exist
    if [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
        log_info "SSL certificates found, starting with HTTPS..."
        
        # Update nginx config with domain
        sed -i "s/server_name _;/server_name $DOMAIN www.$DOMAIN;/g" nginx/nginx.conf
        
        docker compose up -d --build
    else
        log_info "Obtaining SSL certificates..."
        
        # Use initial HTTP-only config
        cp nginx/nginx-init.conf nginx/nginx.conf.bak
        cp nginx/nginx-init.conf nginx/nginx.conf
        
        # Start services
        docker compose up -d --build
        
        # Wait for services to be ready
        log_info "Waiting for services to start..."
        sleep 15
        
        # Get certificate
        docker compose run --rm certbot certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            --email "$EMAIL" \
            --agree-tos \
            --no-eff-email \
            -d "$DOMAIN" \
            -d "www.$DOMAIN"
        
        if [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
            log_success "SSL certificate obtained!"
            
            # Restore full nginx config
            cp nginx/nginx.conf.bak nginx/nginx-init.conf 2>/dev/null || true
            
            # Reset nginx.conf from template and update with domain
            cat > nginx/nginx.conf << 'NGINXCONF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;

    upstream nodejs {
        server app:3000;
        keepalive 64;
    }

    server {
        listen 80;
        listen [::]:80;
        server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$host$request_uri;
        }
    }

    server {
        listen 443 ssl;
        listen [::]:443 ssl;
        http2 on;
        server_name DOMAIN_PLACEHOLDER www.DOMAIN_PLACEHOLDER;

        ssl_certificate /etc/nginx/ssl/live/DOMAIN_PLACEHOLDER/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/live/DOMAIN_PLACEHOLDER/privkey.pem;

        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:50m;
        ssl_session_tickets off;

        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        add_header Strict-Transport-Security "max-age=63072000" always;

        location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
            proxy_pass http://nodejs;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            expires 30d;
            add_header Cache-Control "public, immutable";
        }

        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://nodejs;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        location / {
            limit_req zone=general burst=50 nodelay;
            proxy_pass http://nodejs;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_cache_bypass $http_upgrade;
        }

        location ~ /\. {
            deny all;
        }
    }
}
NGINXCONF
            
            # Replace placeholder with actual domain
            sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" nginx/nginx.conf
            
            # Reload nginx
            docker compose exec nginx nginx -s reload
            
            log_success "HTTPS configured successfully!"
        else
            log_error "Failed to obtain SSL certificate"
            exit 1
        fi
    fi
else
    log_info "Deploying with self-signed SSL (development mode)..."
    
    # Generate self-signed certificates
    if [ ! -f "certbot/conf/fullchain.pem" ]; then
        log_info "Generating self-signed certificates..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout certbot/conf/privkey.pem \
            -out certbot/conf/fullchain.pem \
            -subj "/C=IL/ST=Israel/L=TelAviv/O=Maya Koren/CN=localhost"
    fi
    
    docker compose up -d --build
fi

# Wait for services
log_info "Waiting for services to be ready..."
sleep 10

# Check status
echo ""
log_info "Container status:"
docker compose ps

# Final message
echo ""
echo "=============================================="
log_success "Deployment Complete!"
echo "=============================================="
echo ""
if [ -n "$DOMAIN" ]; then
    echo "Your site is available at: ${GREEN}https://$DOMAIN${NC}"
else
    echo "Your site is available at: ${GREEN}https://localhost${NC}"
    echo "(Browser will show security warning for self-signed certificate)"
fi
echo ""
echo "Admin panel: ${GREEN}https://${DOMAIN:-localhost}/admin${NC}"
echo "Default login: admin / admin"
echo "${RED}Change the password immediately!${NC}"
echo ""
