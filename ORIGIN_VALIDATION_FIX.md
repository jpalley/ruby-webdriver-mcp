# Origin Validation Fix

## Problem

When calling the MCP server in production, requests were failing with:
```json
{"jsonrpc":"2.0","error":{"code":-32600,"message":"Forbidden: Origin validation failed"},"id":null}
```

Additionally, there was a runtime error:
```
ERROR ArgumentError: wrong number of arguments (given 2, expected 1)
  /app/lib/selenium_webdriver_mcp/fast_mcp_patch.rb:17:in `validate_origin'
```

## Root Cause

1. **Wrong Method Signature**: The `validate_origin` override in `fast_mcp_patch.rb` had the wrong signature
   - **Expected by FastMCP**: `def validate_origin(request, env)` (2 arguments)
   - **What we had**: `def validate_origin(env)` (1 argument)

2. **Lack of HTTP Integration Tests**: There were no tests that actually made HTTP requests to the MCP server, so this error wasn't caught during development

## Solution

### 1. Fixed Method Signature

**File**: `lib/selenium_webdriver_mcp/fast_mcp_patch.rb:17`

```ruby
# BEFORE (wrong - only 1 argument)
def validate_origin(env)
  true
end

# AFTER (correct - 2 arguments matching FastMCP's signature)
def validate_origin(request, env)
  true
end
```

### 2. Added HTTP Integration Tests

**File**: `spec/http_integration/http_transport_spec.rb` (NEW)

Created comprehensive HTTP integration tests that:
- Start a real WEBrick server with the MCP Rack app
- Make actual HTTP requests to the MCP endpoints
- Test origin validation bypass (requests from different origins work)
- Test requests without Origin header
- Test MCP protocol initialization
- Test health check endpoint

These tests catch issues that unit tests miss, such as:
- Wrong method signatures in Rack middleware
- Origin validation problems
- Rack/HTTP transport issues
- Header handling problems

## Test Results

**Before Fix**: 114 tests passing
**After Fix**: 118 tests passing (added 4 HTTP integration tests)

All new tests pass:
```
HTTP Transport Integration
  MCP JSON-RPC endpoint
    ✓ handles requests without origin header
    ✓ returns proper JSON-RPC response for initialize method
    ✓ accepts requests without origin validation errors
  Health check endpoint
    ✓ returns OK status
```

## How This Could Have Been Prevented

The HTTP integration tests would have caught this issue immediately. The key lesson is:

**For Rack/HTTP applications, you need integration tests that actually make HTTP requests**, not just unit tests that call Rack apps directly.

The new test suite ensures that:
1. Method signatures match what FastMCP actually calls
2. Origin validation bypass works correctly
3. The full HTTP request/response cycle works end-to-end
4. Production configuration (localhost_only: false) is tested

## Files Changed

1. `lib/selenium_webdriver_mcp/fast_mcp_patch.rb` - Fixed validate_origin signature
2. `spec/http_integration/http_transport_spec.rb` - New HTTP integration test suite

## Verification

To verify the fix works in production:

```bash
# Build and start the container
docker build -t selenium-mcp-server .
docker-compose -f docker-compose.production.yml up

# Test with a request from a different origin
curl -X POST http://localhost:4443/mcp \
  -H "Content-Type: application/json" \
  -H "Origin: http://example.com" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}'

# Should return JSON with tools list, NOT an origin validation error
```
