#!/bin/bash
# Generate self-signed SSL certificates for local development/testing
# Usage: ./scripts/generate-self-signed.sh

set -e

echo "================================================"
echo "Generating Self-Signed SSL Certificates"
echo "================================================"

# Create directories
mkdir -p certbot/conf

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout certbot/conf/privkey.pem \
    -out certbot/conf/fullchain.pem \
    -subj "/C=IL/ST=Israel/L=TelAviv/O=Maya Koren/CN=localhost"

echo "Self-signed certificates generated!"
echo ""
echo "Files created:"
echo "  - certbot/conf/fullchain.pem"
echo "  - certbot/conf/privkey.pem"
echo ""
echo "Note: Browsers will show a security warning for self-signed certificates."
echo "This is normal for development. Click 'Advanced' and proceed."
echo ""
echo "Run 'docker compose up -d' to start the services."
