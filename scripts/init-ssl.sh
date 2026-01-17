#!/bin/bash
# SSL Certificate Initialization Script
# Usage: ./scripts/init-ssl.sh yourdomain.com your@email.com

set -e

DOMAIN=$1
EMAIL=$2

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    echo "Usage: $0 <domain> <email>"
    echo "Example: $0 example.com admin@example.com"
    exit 1
fi

echo "================================================"
echo "SSL Certificate Setup for: $DOMAIN"
echo "Email: $EMAIL"
echo "================================================"

# Create required directories
echo "Creating directories..."
mkdir -p certbot/conf certbot/www

# Check if certificates already exist
if [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    echo "Certificates already exist for $DOMAIN"
    echo "To renew, run: docker compose run --rm certbot renew"
    exit 0
fi

# Use init config for nginx (HTTP only)
echo "Setting up nginx with initial config..."
cp nginx/nginx-init.conf nginx/nginx.conf.bak
cp nginx/nginx-init.conf nginx/nginx.conf

# Start services with HTTP only
echo "Starting services..."
docker compose up -d nginx app db

# Wait for nginx to be ready
echo "Waiting for nginx to be ready..."
sleep 10

# Request certificate
echo "Requesting certificate from Let's Encrypt..."
docker compose run --rm certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    -d "$DOMAIN" \
    -d "www.$DOMAIN"

# Check if certificate was obtained
if [ -f "certbot/conf/live/$DOMAIN/fullchain.pem" ]; then
    echo "Certificate obtained successfully!"
    
    # Create symlinks for nginx
    echo "Setting up certificate symlinks..."
    mkdir -p certbot/conf/live/$DOMAIN
    
    # Restore full nginx config with SSL
    echo "Switching to HTTPS nginx config..."
    mv nginx/nginx.conf.bak nginx/nginx-init.conf
    
    # Update nginx.conf with actual domain
    sed -i "s/server_name _;/server_name $DOMAIN www.$DOMAIN;/g" nginx/nginx.conf
    
    # Reload nginx
    echo "Reloading nginx..."
    docker compose exec nginx nginx -s reload
    
    echo "================================================"
    echo "SSL Setup Complete!"
    echo "Your site is now available at: https://$DOMAIN"
    echo "================================================"
else
    echo "ERROR: Certificate not obtained. Check the logs above."
    # Restore original config
    mv nginx/nginx.conf.bak nginx/nginx.conf
    exit 1
fi
