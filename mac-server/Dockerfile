FROM node:18-slim

# Install build dependencies for node-pty and zsh
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid appgroup --shell /bin/zsh --create-home appuser

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

# Create directories for token and logs, owned by appuser
RUN mkdir -p /data && chown -R appuser:appgroup /data
RUN chown -R appuser:appgroup /app

# Expose WebSocket port
EXPOSE 8765

# Set environment variables
ENV NODE_ENV=production

# Switch to non-root user
USER appuser

# Use entrypoint script
ENTRYPOINT ["./docker-entrypoint.sh"]
