# Use Node.js LTS Alpine for smaller image
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install dependencies first (better layer caching)
COPY package*.json ./
RUN npm ci --omit=dev

# Copy application files
COPY . .

# Create uploads directory with correct permissions
RUN mkdir -p /app/assets/uploads

# Use non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/admin/status || exit 1

# Start the application
CMD ["node", "server.js"]
