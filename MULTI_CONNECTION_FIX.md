# Multi-Connection Race Condition Fix

## Issue
When multiple MCP clients connected to the server simultaneously, the second (and subsequent) connections would receive errors like:

```json
{
  "code": "invalid_union",
  "unionErrors": [
    {
      "issues": [
        {
          "code": "invalid_type",
          "expected": "object",
          "received": "null"
        }
      ]
    }
  ]
}
```

## Root Cause
The issue was a **race condition in `lib/selenium_webdriver_mcp/fast_mcp_patch.rb`**:

1. The patch uses instance variables (`@capturing_sync_response`, `@sync_response_capture`) to capture HTTP POST responses
2. In multi-threaded web servers (WEBrick, Puma, etc.), all concurrent requests share the **same RackTransport instance**
3. When Request A and Request B arrive concurrently:
   - Request A sets `@capturing_sync_response = true`
   - Request B sets `@capturing_sync_response = true` (same instance variable!)
   - Request A calls `send_message`, stores Response A in `@sync_response_capture`
   - Request B calls `send_message`, **overwrites** `@sync_response_capture` with Response B
   - Request A reads `@sync_response_capture` and gets **Response B** (wrong!)
   - Request B reads `@sync_response_capture` and gets Response B (correct)

This caused requests to receive the wrong responses, or null/empty responses if timing was off.

## Solution
Changed the patch to use **thread-local storage** (`Thread.current`) instead of instance variables:

**Before (buggy):**
```ruby
# Instance variables - shared across all threads!
@capturing_sync_response = true
@sync_response_capture = nil

# Later...
if @capturing_sync_response
  @sync_response_capture = json_message
end

# Later...
response_json = @sync_response_capture
```

**After (fixed):**
```ruby
# Thread-local storage - each thread has its own copy!
Thread.current[:mcp_capturing_sync_response] = true
Thread.current[:mcp_sync_response_capture] = nil

# Later...
if Thread.current[:mcp_capturing_sync_response]
  Thread.current[:mcp_sync_response_capture] = json_message
end

# Later...
response_json = Thread.current[:mcp_sync_response_capture]
```

## Changes Made
- **lib/selenium_webdriver_mcp/fast_mcp_patch.rb**:
  - Line 26: Changed `@capturing_sync_response` → `Thread.current[:mcp_capturing_sync_response]`
  - Line 28: Changed `@sync_response_capture` → `Thread.current[:mcp_sync_response_capture]`
  - Lines 54-55: Changed instance variables → thread-local variables
  - Lines 61-69: Changed instance variables → thread-local variables in response capture and cleanup

## Testing
Added comprehensive concurrent request tests in `spec/integration_driver_only/multi_connection_spec.rb`:
- **Basic tests (4)**: Initialize, sequential requests, 5 concurrent connections
- **Advanced 3-client workflow tests (6)**:
  - Concurrent initialization
  - Concurrent tool listing
  - Session creation and management
  - 30 interleaved requests (3 clients × 10 requests each)
  - Real browser navigation and element interaction
  - Multiple pages accessed simultaneously with different interactions

**Key test scenarios**:
- 3 concurrent clients each navigate to web pages and interact with elements
- Client 1: Navigate to simple.html, find and click H1
- Client 2: Navigate to form.html, find username input and type text
- Client 3: Navigate to simple.html, find and click paragraph
- All operations happen in parallel, verifying complete session isolation

All 10 multi-connection tests pass (plus 218 total tests pass).

## Impact
- **Before**: Multiple simultaneous connections would fail with "invalid_union" errors or receive wrong responses
- **After**: Multiple connections work correctly, each receiving its own response without interference

## Why This Happened
The original patch was written to fix a bug in fast-mcp 1.6.0 where HTTP POST responses weren't being returned correctly. The patch worked fine for single-threaded scenarios but didn't account for concurrent requests in production deployments using multi-threaded web servers.
