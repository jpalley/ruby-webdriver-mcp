# MCP Endpoint Path Changes

## Summary

The MCP server endpoint paths have been simplified for easier access and cleaner URLs.

## What Changed

### Old Endpoints
- **HTTP JSON-RPC**: `POST /mcp/messages`
- **Server-Sent Events**: `GET /mcp/sse`
- **Health Check**: `GET /health` (unchanged)

### New Endpoints
- **HTTP JSON-RPC**: `POST /mcp`
- **Server-Sent Events**: `GET /sse`
- **Health Check**: `GET /health` (unchanged)

## Rationale

1. **Simpler URLs**: `/mcp` is shorter and more intuitive than `/mcp/messages`
2. **Clearer Purpose**: `/sse` clearly indicates Server-Sent Events without nesting
3. **Consistency**: Both endpoints are now at the root level

## Implementation Details

The endpoint paths are configured in `lib/selenium_webdriver_mcp/server.rb` by setting FastMCP's RackTransport options:

```ruby
# Configure custom endpoint paths
# Set path_prefix to '' (empty) so we can use /mcp and /sse directly
options[:path_prefix] ||= ''
options[:messages_route] ||= 'mcp'
options[:sse_route] ||= 'sse'
```

This configuration:
- Sets `path_prefix` to empty string (no prefix like `/mcp`)
- Sets `messages_route` to `'mcp'` (results in `/mcp`)
- Sets `sse_route` to `'sse'` (results in `/sse`)

## Testing

All 118 tests pass with the new endpoint paths, including:
- 4 HTTP integration tests that make actual HTTP requests
- 35 MCP integration tests that call tools via the MCP protocol
- All unit and driver integration tests

## Migration Guide

If you have existing code calling the old endpoints, update your URLs:

### Before
```bash
curl -X POST http://localhost:4443/mcp/messages \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

### After
```bash
curl -X POST http://localhost:4443/mcp \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
```

## Documentation Updated

The following documentation files have been updated with the new endpoints:

1. `README.md` - Quick start examples and architecture diagram
2. `DOCKER.md` - Docker deployment guide
3. `DEPLOYMENT_SUMMARY.md` - Deployment summary
4. `config.ru` - Endpoint comments
5. `ORIGIN_VALIDATION_FIX.md` - Testing examples

## Backwards Compatibility

**Note**: The old endpoints (`/mcp/messages` and `/mcp/sse`) are **not** supported. All clients must update to use the new endpoint paths.

If you need to support both old and new endpoints during a migration period, you would need to:
1. Configure the FastMCP RackTransport with the old paths
2. Add custom routing middleware to handle both paths

However, this is not currently implemented as this is a new deployment.
