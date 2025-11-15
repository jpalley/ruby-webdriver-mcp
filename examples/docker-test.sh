#!/bin/bash
# Test script for Docker deployment

set -e

echo "=== Selenium WebDriver MCP Server - Docker Test ==="
echo ""

# Check Docker is installed
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed"
    exit 1
fi

echo "✓ Docker is installed"

# Build the image
echo ""
echo "Building Docker image..."
docker build -t selenium-mcp-server .

echo "✓ Docker image built successfully"

# Start with docker-compose
echo ""
echo "Starting services with docker-compose..."
docker-compose -f docker-compose.production.yml up -d

echo "✓ Services started"

# Wait for services to be ready
echo ""
echo "Waiting for services to be ready..."
sleep 10

# Test health endpoint
echo ""
echo "Testing health endpoint..."
HEALTH_RESPONSE=$(curl -s http://localhost:9292/health)
echo "Response: $HEALTH_RESPONSE"

if echo "$HEALTH_RESPONSE" | grep -q "ok"; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
    docker-compose -f docker-compose.production.yml logs
    exit 1
fi

# Test tools/list endpoint
echo ""
echo "Testing MCP tools/list endpoint..."
TOOLS_RESPONSE=$(curl -s -X POST http://localhost:9292/mcp/messages \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }')

if echo "$TOOLS_RESPONSE" | grep -q "create_session"; then
    echo "✓ MCP server is responding correctly"
    echo "Available tools:"
    echo "$TOOLS_RESPONSE" | jq -r '.result.tools[].name' 2>/dev/null || echo "$TOOLS_RESPONSE"
else
    echo "✗ MCP server not responding correctly"
    echo "Response: $TOOLS_RESPONSE"
    exit 1
fi

# Test creating a session
echo ""
echo "Testing session creation..."
SESSION_RESPONSE=$(curl -s -X POST http://localhost:9292/mcp/messages \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "create_session",
      "arguments": {}
    }
  }')

if echo "$SESSION_RESPONSE" | grep -q "session_id"; then
    echo "✓ Browser session created successfully"
else
    echo "✗ Failed to create browser session"
    echo "Response: $SESSION_RESPONSE"
    exit 1
fi

echo ""
echo "=== All tests passed! ==="
echo ""
echo "Services are running:"
echo "  - MCP Server: http://localhost:9292"
echo "  - Selenium: http://localhost:4444"
echo "  - VNC Viewer: vnc://localhost:7900 (password: secret)"
echo ""
echo "To stop services:"
echo "  docker-compose -f docker-compose.production.yml down"
