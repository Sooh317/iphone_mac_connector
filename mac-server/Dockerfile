FROM node:18-slim

# Install build dependencies for node-pty and zsh
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application source
COPY src/ ./src/
COPY scripts/ ./scripts/
COPY config.json.example ./
COPY docker-entrypoint.sh ./

# Make entrypoint executable
RUN chmod +x docker-entrypoint.sh

# Create directories for token and logs
RUN mkdir -p /data

# Expose WebSocket port
EXPOSE 8765

# Set environment variables
ENV NODE_ENV=production

# Use entrypoint script
ENTRYPOINT ["./docker-entrypoint.sh"]
