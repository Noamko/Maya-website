#!/bin/bash
#
# Maya Website - Deployment Script
# Quick deployment for fresh server or updates
#
# Usage:
#   ./scripts/deploy.sh                                    # Deploy for localhost (dev)
#   ./scripts/deploy.sh elishasconcept.com admin@email.com # Deploy with domain + SSL
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
echo "  Maya Website - Deployment (Caddy)"
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
# Database Configuration
POSTGRES_USER=maya_user
POSTGRES_PASSWORD=$DB_PASSWORD
POSTGRES_DB=maya_website

# Application Configuration
NODE_ENV=production
PORT=3000
SESSION_SECRET=$SESSION_SECRET

# Domain Configuration
DOMAIN=${DOMAIN:-localhost}
DOMAIN_URL=$DOMAIN_URL
FRONTEND_URL=$DOMAIN_URL

# Let's Encrypt Email (required for production SSL)
ACME_EMAIL=${EMAIL:-admin@example.com}
EOF
    
    chmod 600 .env
    log_success "Created .env with secure credentials"
else
    # Update domain settings if provided
    if [ -n "$DOMAIN" ]; then
        log_info "Updating domain configuration..."
        sed -i "s|^DOMAIN=.*|DOMAIN=$DOMAIN|g" .env
        sed -i "s|^DOMAIN_URL=.*|DOMAIN_URL=https://$DOMAIN|g" .env
        sed -i "s|^FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|g" .env
    fi
    if [ -n "$EMAIL" ]; then
        sed -i "s|^ACME_EMAIL=.*|ACME_EMAIL=$EMAIL|g" .env
    fi
fi

# Create necessary directories
mkdir -p assets/uploads backups

# Stop existing containers
log_info "Stopping existing containers..."
docker compose down 2>/dev/null || true

# Build and start
log_info "Building and starting services..."
docker compose up -d --build

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
    echo -e "Your site is available at: ${GREEN}https://$DOMAIN${NC}"
    echo ""
    echo "Caddy will automatically obtain SSL certificates from Let's Encrypt."
    echo "This may take a minute on first startup."
else
    echo -e "Your site is available at: ${GREEN}https://localhost${NC}"
    echo "(Caddy will use a self-signed certificate for localhost)"
fi
echo ""
echo -e "Admin panel: ${GREEN}https://${DOMAIN:-localhost}/admin${NC}"
echo "Default login: admin / admin"
echo -e "${RED}Change the password immediately!${NC}"
echo ""
