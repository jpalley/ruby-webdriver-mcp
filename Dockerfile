# Production Dockerfile for Selenium WebDriver MCP Server
# This runs the MCP server only - Selenium should be running separately

FROM ruby:3.2-slim

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy everything (excluding what's in .dockerignore)
COPY . .

# Install Ruby dependencies
RUN bundle install --without development test

# Environment variables with defaults
# These can be overridden at runtime with docker run -e
ENV SELENIUM_URL=http://selenium:4444/wd/hub \
    SELENIUM_BROWSER=chrome \
    SELENIUM_HEADLESS=true \
    PORT=4443 \
    RACK_ENV=production

# Expose the MCP server port
EXPOSE 4443

# Health check - verify the server is responding
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:${PORT}/health || exit 1

# Run the MCP server
CMD ["sh", "-c", "bundle exec rackup -o 0.0.0.0 -p ${PORT} config.ru"]
