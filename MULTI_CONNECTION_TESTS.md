# Multi-Connection Test Suite

## Overview
Comprehensive test suite demonstrating that the MCP server correctly handles multiple concurrent connections without race conditions or response mixing.

## Tests Summary

### Basic Tests (4 tests)
1. **handles first connection initialize request** - Verifies basic MCP protocol initialization
2. **handles second connection initialize request** - Verifies a second client can initialize independently
3. **handles multiple sequential requests** - 3 clients making sequential initialize requests
4. **handles truly concurrent requests without race conditions** - 5 clients initializing simultaneously, verifying each gets correct response ID

### Advanced 3-Client Workflow Tests (6 tests)

#### Test 1: handles 3 clients each initializing concurrently
- **What it does**: 3 clients simultaneously send initialize requests
- **Verifies**: Each client receives correct server info with matching request ID

#### Test 2: handles 3 clients each listing tools concurrently
- **What it does**: 3 clients initialize, then simultaneously request tools/list
- **Verifies**: All clients receive identical tools list (11 tools) with correct IDs

#### Test 3: handles 3 clients creating sessions and performing operations concurrently
- **What it does**: Each client creates a custom session, then destroys it
- **Verifies**: All session operations complete successfully

#### Test 4: handles 3 clients with interleaved requests in random order
- **What it does**: 3 clients each make 10 requests with random delays to maximize interleaving
- **Verifies**: All 30 requests receive correct responses with matching IDs (no response mixing)

#### Test 5: maintains session isolation across 3 concurrent clients
- **What it does**: 3 clients each create a session, navigate to simple.html, find and click an H1 element
- **Verifies**:
  - Each session is isolated and independent
  - Each client successfully navigates to web page
  - Each client can find and interact with elements
  - All browsers run in parallel without interference

#### Test 6: handles 3 clients simultaneously navigating and interacting with different pages
- **What it does**: 3 clients access different pages concurrently:
  - Client 0: Navigate to simple.html, find and click H1
  - Client 1: Navigate to form.html, find username field and type text
  - Client 2: Navigate to simple.html, find and click paragraph
- **Verifies**:
  - All 3 browser sessions operate independently and in parallel
  - Different pages can be accessed simultaneously
  - Different interactions (click vs send_keys) work concurrently
  - Element caches are isolated (all find `element_0` in their own cache)

## Key Features Demonstrated

### 1. Request/Response Isolation
- Multiple concurrent requests receive correct responses
- Response IDs match request IDs perfectly
- No response mixing or null responses

### 2. Session Isolation
- Each client can create and manage independent browser sessions
- Sessions operate concurrently without interference
- Element caches are per-session (not global)

### 3. Real Browser Operations
- Concurrent navigation to web pages
- Concurrent element finding and clicking
- Concurrent form interactions (typing into inputs)
- Multiple different pages accessed simultaneously

### 4. Thread Safety
- Tests run in Ruby threads simulating concurrent HTTP requests
- No race conditions in response capture
- No session manager conflicts
- No WebDriver connection issues

## Technical Implementation

### Race Condition Fix
The tests verify the fix in `lib/selenium_webdriver_mcp/fast_mcp_patch.rb` which uses thread-local storage instead of instance variables to capture responses:

**Before (buggy)**:
```ruby
@capturing_sync_response = true  # Shared across all threads!
@sync_response_capture = response
```

**After (fixed)**:
```ruby
Thread.current[:mcp_capturing_sync_response] = true  # Per-thread!
Thread.current[:mcp_sync_response_capture] = response
```

### Test Architecture
- Uses `Rack::Test::Methods` for simulating HTTP requests
- Spawns Ruby threads to simulate concurrent MCP clients
- Uses TestHtmlServer to serve real HTML pages to browsers
- Connects to actual Selenium WebDriver for real browser automation

## Running the Tests

```bash
# Run all multi-connection tests
bundle exec rspec spec/integration_driver_only/multi_connection_spec.rb

# Run with documentation format
bundle exec rspec spec/integration_driver_only/multi_connection_spec.rb --format documentation
```

## Test Results
✅ All 10 tests pass
✅ Tests run in ~3-5 seconds
✅ Demonstrates robust concurrent handling

## Conclusion
The test suite comprehensively proves that the MCP server can handle multiple simultaneous connections with:
- No response mixing
- Proper session isolation
- Real browser automation in parallel
- Thread-safe operations throughout the stack
