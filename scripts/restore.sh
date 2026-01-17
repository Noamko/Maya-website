#!/bin/bash

# Database Restore Script for Maya Website
# This script restores a PostgreSQL database from a backup
#
# Usage:
#   ./scripts/restore.sh backup_file.sql.gz

set -e

# Configuration
CONTAINER_NAME="maya-postgres"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Maya Website Database Restore${NC}"
echo -e "${GREEN}  $(date)${NC}"
echo -e "${GREEN}========================================${NC}"

# Check if backup file is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: No backup file specified${NC}"
    echo -e "Usage: $0 <backup_file.sql.gz>"
    echo -e "\nAvailable backups:"
    ls -lh ./backups/maya_website_backup_*.sql.gz 2>/dev/null || echo "No backups found in ./backups/"
    exit 1
fi

BACKUP_FILE="$1"

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    echo -e "${RED}Error: Backup file '$BACKUP_FILE' not found${NC}"
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${RED}Error: Container '${CONTAINER_NAME}' is not running${NC}"
    exit 1
fi

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Set defaults if not in environment
POSTGRES_USER="${POSTGRES_USER:-maya_user}"
POSTGRES_DB="${POSTGRES_DB:-maya_website}"

echo -e "${YELLOW}WARNING: This will overwrite the current database!${NC}"
echo -e "Backup file: ${BACKUP_FILE}"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Restore cancelled${NC}"
    exit 0
fi

echo -e "${YELLOW}Restoring database...${NC}"

# Decompress if gzipped
if [[ "$BACKUP_FILE" == *.gz ]]; then
    echo -e "Decompressing backup..."
    gunzip -c "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        --quiet
else
    docker exec -i "$CONTAINER_NAME" psql \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        --quiet < "$BACKUP_FILE"
fi

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database restored successfully!${NC}"
else
    echo -e "${RED}✗ Restore failed!${NC}"
    exit 1
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Restore complete!${NC}"
echo -e "${GREEN}========================================${NC}"
