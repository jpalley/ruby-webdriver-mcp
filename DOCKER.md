# Docker Deployment Guide

This guide explains how to run the Selenium WebDriver MCP Server using Docker.

## Quick Start

### Using Docker Compose (Recommended)

Run the MCP server with Selenium in separate containers:

```bash
docker-compose -f docker-compose.production.yml up
```

The MCP server will be available at `http://localhost:9292`

### Using Docker Build

Build and run the MCP server container:

```bash
# Build the image
docker build -t selenium-mcp-server .

# Run with default settings (expects Selenium at selenium:4444)
docker run -p 9292:9292 selenium-mcp-server

# Run with custom Selenium URL
docker run -p 9292:9292 \
  -e SELENIUM_URL=http://your-selenium-host:4444/wd/hub \
  selenium-mcp-server
```

## Environment Variables

Configure the server using these environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `SELENIUM_URL` | `http://selenium:4444/wd/hub` | Selenium WebDriver endpoint URL |
| `SELENIUM_BROWSER` | `chrome` | Browser to use (chrome, firefox, edge) |
| `SELENIUM_HEADLESS` | `true` | Run browser in headless mode |
| `PORT` | `9292` | HTTP port for MCP server |
| `RACK_ENV` | `production` | Rack environment |

## Endpoints

Once running, the server exposes:

- **Health Check**: `GET /health`
  - Returns JSON with status and version
  - Used by Docker healthcheck

- **MCP Messages**: `POST /mcp`
  - JSON-RPC 2.0 endpoint for tool calls
  - Main endpoint for MCP clients

- **MCP SSE**: `GET /sse`
  - Server-Sent Events endpoint
  - For real-time updates

## Testing the Server

### Health Check

```bash
curl http://localhost:9292/health
# {"status":"ok","version":"0.1.0"}
```

### List Available Tools

```bash
curl -X POST http://localhost:9292/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/list"
  }'
```

### Create a Browser Session

```bash
curl -X POST http://localhost:9292/mcp \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "id": 2,
    "method": "tools/call",
    "params": {
      "name": "create_session",
      "arguments": {}
    }
  }'
```

## Production Deployment

### With External Selenium Grid

If you have a separate Selenium Grid:

```bash
docker run -d \
  --name mcp-server \
  -p 9292:9292 \
  -e SELENIUM_URL=http://your-selenium-grid:4444/wd/hub \
  -e SELENIUM_BROWSER=chrome \
  -e SELENIUM_HEADLESS=true \
  --restart unless-stopped \
  selenium-mcp-server
```

### With Docker Compose

For a complete setup with Selenium:

```yaml
# docker-compose.yml
version: '3.8'

services:
  mcp-server:
    image: selenium-mcp-server
    ports:
      - "9292:9292"
    environment:
      SELENIUM_URL: http://selenium:4444/wd/hub
    depends_on:
      - selenium

  selenium:
    image: selenium/standalone-chrome:latest
    shm_size: 2gb
    ports:
      - "4444:4444"
```

## Debugging

### View Selenium Browser (VNC)

When using the provided `docker-compose.production.yml`, you can view the browser via VNC:

1. Connect VNC client to `localhost:7900`
2. Password: `secret`
3. Watch browser automation in real-time

### Container Logs

```bash
# MCP Server logs
docker-compose -f docker-compose.production.yml logs -f mcp-server

# Selenium logs
docker-compose -f docker-compose.production.yml logs -f selenium
```

### Check Selenium Status

```bash
curl http://localhost:4444/wd/hub/status
```

## Security Considerations

For production deployment:

1. **Authentication**: The MCP server doesn't include authentication by default. Use a reverse proxy (nginx, Traefik) with authentication.

2. **Network Isolation**: Run containers in a private network:
   ```bash
   docker network create --internal mcp-internal
   ```

3. **Resource Limits**: Set memory/CPU limits:
   ```yaml
   services:
     mcp-server:
       deploy:
         resources:
           limits:
             cpus: '1'
             memory: 512M
   ```

4. **Environment Variables**: Use Docker secrets or external secret management instead of plain environment variables for sensitive data.

## Scaling

To handle multiple concurrent sessions:

1. **Increase Selenium nodes**:
   ```yaml
   environment:
     SE_NODE_MAX_SESSIONS: 20
   ```

2. **Run multiple MCP server instances** behind a load balancer

3. **Use Selenium Grid** with multiple nodes instead of standalone

## Troubleshooting

### "Connection refused" errors

- Check Selenium is running: `curl http://localhost:4444/wd/hub/status`
- Verify SELENIUM_URL environment variable
- Ensure containers are on the same network

### "Session not created" errors

- Check Selenium has enough resources (increase shm_size)
- Verify browser compatibility
- Check Selenium logs for detailed errors

### Health check failing

- Verify port 9292 is accessible
- Check container logs for startup errors
- Ensure all dependencies are installed

## Examples

See the `examples/` directory for:
- Claude Desktop MCP configuration
- Python client examples
- JavaScript/Node.js client examples
