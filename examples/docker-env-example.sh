#!/bin/bash
# Example: Running MCP server with custom environment variables

# Example 1: Basic usage with default settings
echo "Example 1: Default configuration"
docker run -p 9292:9292 selenium-mcp-server

# Example 2: Custom Selenium URL (external Selenium Grid)
echo "Example 2: External Selenium Grid"
docker run -p 9292:9292 \
  -e SELENIUM_URL=http://selenium-grid.company.com:4444/wd/hub \
  selenium-mcp-server

# Example 3: Firefox browser instead of Chrome
echo "Example 3: Firefox browser"
docker run -p 9292:9292 \
  -e SELENIUM_URL=http://selenium:4444/wd/hub \
  -e SELENIUM_BROWSER=firefox \
  selenium-mcp-server

# Example 4: Non-headless mode (useful for debugging)
echo "Example 4: Non-headless mode"
docker run -p 9292:9292 \
  -e SELENIUM_URL=http://selenium:4444/wd/hub \
  -e SELENIUM_HEADLESS=false \
  selenium-mcp-server

# Example 5: Custom port
echo "Example 5: Custom port"
docker run -p 8080:8080 \
  -e PORT=8080 \
  -e SELENIUM_URL=http://selenium:4444/wd/hub \
  selenium-mcp-server

# Example 6: Using .env file
echo "Example 6: Using .env file"
cat > .env <<EOF
SELENIUM_URL=http://selenium:4444/wd/hub
SELENIUM_BROWSER=chrome
SELENIUM_HEADLESS=true
PORT=9292
EOF

docker run -p 9292:9292 --env-file .env selenium-mcp-server

# Example 7: Production deployment with restart policy
echo "Example 7: Production deployment"
docker run -d \
  --name mcp-server \
  --restart unless-stopped \
  -p 9292:9292 \
  -e SELENIUM_URL=http://selenium:4444/wd/hub \
  -e SELENIUM_BROWSER=chrome \
  -e SELENIUM_HEADLESS=true \
  selenium-mcp-server

# Example 8: With resource limits
echo "Example 8: Resource limits"
docker run -d \
  --name mcp-server \
  --memory=512m \
  --cpus=1 \
  -p 9292:9292 \
  -e SELENIUM_URL=http://selenium:4444/wd/hub \
  selenium-mcp-server

# Example 9: With custom network (for container-to-container communication)
echo "Example 9: Custom network"
docker network create mcp-network
docker run -d \
  --name mcp-server \
  --network mcp-network \
  -p 9292:9292 \
  -e SELENIUM_URL=http://selenium:4444/wd/hub \
  selenium-mcp-server

# Example 10: With volume mount for logs
echo "Example 10: With logging"
docker run -d \
  --name mcp-server \
  -v ./logs:/app/logs \
  -p 9292:9292 \
  -e SELENIUM_URL=http://selenium:4444/wd/hub \
  selenium-mcp-server
