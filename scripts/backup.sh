#!/bin/bash

# Database Backup Script for Maya Website
# This script creates a backup of the PostgreSQL database
# 
# Usage:
#   ./scripts/backup.sh                    # Creates backup in ./backups/
#   ./scripts/backup.sh /path/to/backups   # Creates backup in specified directory
#
# Recommended: Add to crontab for automatic daily backups
#   0 3 * * * /path/to/Maya-website/scripts/backup.sh >> /var/log/maya-backup.log 2>&1

set -e

# Configuration
BACKUP_DIR="${1:-./backups}"
CONTAINER_NAME="maya-postgres"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="maya_website_backup_${TIMESTAMP}.sql"
KEEP_DAYS=7  # Number of days to keep backups

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Maya Website Database Backup${NC}"
echo -e "${GREEN}  $(date)${NC}"
echo -e "${GREEN}========================================${NC}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

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

echo -e "${YELLOW}Creating backup...${NC}"

# Create the backup using pg_dump
docker exec "$CONTAINER_NAME" pg_dump \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    --no-owner \
    --no-acl \
    > "${BACKUP_DIR}/${BACKUP_FILE}"

# Check if backup was successful
if [ $? -eq 0 ] && [ -s "${BACKUP_DIR}/${BACKUP_FILE}" ]; then
    # Compress the backup
    gzip "${BACKUP_DIR}/${BACKUP_FILE}"
    FINAL_FILE="${BACKUP_DIR}/${BACKUP_FILE}.gz"
    
    # Get file size
    FILE_SIZE=$(du -h "$FINAL_FILE" | cut -f1)
    
    echo -e "${GREEN}✓ Backup created successfully!${NC}"
    echo -e "  File: ${FINAL_FILE}"
    echo -e "  Size: ${FILE_SIZE}"
else
    echo -e "${RED}✗ Backup failed!${NC}"
    rm -f "${BACKUP_DIR}/${BACKUP_FILE}"
    exit 1
fi

# Clean up old backups
echo -e "${YELLOW}Cleaning up backups older than ${KEEP_DAYS} days...${NC}"
DELETED=$(find "$BACKUP_DIR" -name "maya_website_backup_*.sql.gz" -mtime +$KEEP_DAYS -delete -print | wc -l)
echo -e "${GREEN}✓ Deleted ${DELETED} old backup(s)${NC}"

# List current backups
echo -e "\n${YELLOW}Current backups:${NC}"
ls -lh "$BACKUP_DIR"/maya_website_backup_*.sql.gz 2>/dev/null || echo "No backups found"

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Backup complete!${NC}"
echo -e "${GREEN}========================================${NC}"
