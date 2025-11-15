# Threading Fix: "stream closed in another thread" Error

## Problem Summary

The application was experiencing `"stream closed in another thread"` errors when MCP tools were called after session creation. This occurred because:

1. **WEBrick Threading Model**: WEBrick spawns a new thread for each HTTP request
2. **Session Persistence**: Sessions persist across requests and are stored in SessionManager
3. **Net::HTTP Not Thread-Safe**: Selenium WebDriver's default HTTP client uses Net::HTTP, which maintains a single socket connection that is NOT thread-safe
4. **Cross-Thread Access**: When `create_session` runs in Thread A and `navigate` runs in Thread B, both threads try to use the same Net::HTTP socket, causing connection errors

### Error Stack Trace
```
Error: stream closed in another thread, /home/vscode/.rbenv/versions/3.2.3/lib/ruby/3.2.0/net/protocol.rb:229:in `wait_readable'
```

## Solution

We implemented a **hybrid thread-safety approach** combining multiple strategies:

### 1. Custom ThreadSafeHttpClient (`lib/selenium_webdriver_mcp/thread_safe_http_client.rb`)

Created a custom HTTP client that extends Selenium's default client and wraps all HTTP operations in a Mutex:

```ruby
class ThreadSafeHttpClient < Selenium::WebDriver::Remote::Http::Default
  def initialize(open_timeout: nil, read_timeout: nil)
    super(open_timeout: open_timeout, read_timeout: read_timeout)
    @mutex = Mutex.new
  end

  def call(verb, url, command_hash)
    @mutex.synchronize do
      super(verb, url, command_hash)
    end
  end
end
```

**Benefits:**
- Serializes all HTTP requests to Selenium Grid
- Prevents concurrent access to the underlying Net::HTTP socket
- Maintains connection reuse for performance
- Transparent to the rest of the application

### 2. DriverManager Updates

Modified `DriverManager#start` to use the custom HTTP client:

```ruby
def start(retry_count: 0)
  # Create thread-safe HTTP client
  http_client = ThreadSafeHttpClient.new(
    open_timeout: 60,
    read_timeout: 60
  )

  @driver_mutex.synchronize do
    @driver = Selenium::WebDriver.for(
      :remote,
      url: @config.selenium_url,
      options: @config.browser_options,
      http_client: http_client  # Inject our thread-safe client
    )
    # ... configure timeouts
  end
end
```

### 3. Additional Mutex Protection

Added `@driver_mutex` to protect:
- Driver initialization
- Driver cleanup (quit)
- Element cache operations (to prevent race conditions)

```ruby
def cache_element(element)
  @driver_mutex.synchronize do
    element_id = "element_#{@element_cache.size}"
    @element_cache[element_id] = element
    element_id
  end
end
```

## Testing

### Comprehensive Thread Safety Tests

Created `spec/integration_driver_only/thread_safety_spec.rb` with tests that verify:

1. **Concurrent Access to Same Session**: Multiple threads operating on the same session simultaneously
2. **Cross-Thread Session Usage**: Session created in Thread A, used in Thread B (the exact bug scenario)
3. **Rapid Concurrent Operations**: 10 threads all finding elements concurrently
4. **Multiple Concurrent Sessions**: 5 sessions created and used in parallel

### Test Results

```bash
$ bundle exec rspec spec/integration_driver_only/thread_safety_spec.rb

Thread Safety
  concurrent access to the same session
    ✓ handles multiple threads operating on the same session without errors
    ✓ handles create_session followed by navigate in different threads
    ✓ handles rapid concurrent operations without race conditions
  concurrent sessions
    ✓ handles multiple threads with different sessions

Finished in 7.26 seconds
4 examples, 0 failures
```

### Full Integration Test Suite

All 74 existing integration tests pass without regressions:

```bash
$ bundle exec rspec spec/integration_driver_only/

Finished in 42.12 seconds
74 examples, 0 failures
```

## Architecture Benefits

✅ **Thread-Safe**: Prevents "stream closed in another thread" errors
✅ **Performance**: Maintains HTTP connection reuse
✅ **Minimal Changes**: Localized to DriverManager and new HTTP client
✅ **Backward Compatible**: No API changes, existing code continues to work
✅ **Well-Tested**: Comprehensive thread safety tests ensure robustness
✅ **Production-Ready**: Works with any Rack-compatible web server (WEBrick, Puma, Passenger, etc.)

## Files Modified

1. **Created**: `lib/selenium_webdriver_mcp/thread_safe_http_client.rb`
   - Custom HTTP client with mutex protection

2. **Modified**: `lib/selenium_webdriver_mcp/driver_manager.rb`
   - Added `@driver_mutex` instance variable
   - Modified `start` to use ThreadSafeHttpClient
   - Protected `quit` with mutex
   - Protected element cache operations with mutex

3. **Created**: `spec/integration_driver_only/thread_safety_spec.rb`
   - Comprehensive multi-threaded integration tests

4. **Modified**: `CLAUDE.md`
   - Added thread safety documentation
   - Explained threading architecture
   - Added testing guidelines

## How It Works in Production

### Request Flow

1. **Request 1 (Thread A)**: `POST /mcp` → `create_session`
   - SessionManager creates new session
   - DriverManager initialized with ThreadSafeHttpClient
   - Returns session_id to client

2. **Request 2 (Thread B)**: `POST /mcp` → `navigate(session_id, url)`
   - SessionManager retrieves existing DriverManager
   - DriverManager.navigate_to(url) is called
   - ThreadSafeHttpClient acquires mutex
   - Makes HTTP request to Selenium Grid
   - Releases mutex
   - Returns successfully

### Thread Safety Guarantees

- **HTTP Layer**: ThreadSafeHttpClient mutex prevents concurrent HTTP requests
- **Driver Layer**: @driver_mutex prevents concurrent driver access
- **Session Layer**: SessionManager mutex prevents concurrent session modifications
- **Cache Layer**: Element cache operations are atomic

## Monitoring & Debugging

### Thread Logging

All operations log their thread ID for debugging:

```
[Thread 6140] Creating session session_abc123 (current count: 0)
[Thread 6140] Session session_abc123 created successfully (new count: 1)
[Thread 6160] Navigating to: http://example.com
[Thread 6160] Navigation successful: http://example.com
```

### Common Issues

If you still see threading errors:

1. Check that all DriverManager instances use ThreadSafeHttpClient
2. Verify Selenium Grid is running and accessible
3. Check for custom HTTP clients bypassing our implementation
4. Review thread safety test failures for specific scenarios

## Related Issues

- Selenium Issue #8413: "Ruby: sporadic 'stream closed in another thread' IOError"
- Root cause: Net::HTTP is not thread-safe when shared across threads
- Similar to database connection pool issues in Rails

## Conclusion

This fix implements proper thread safety for Selenium WebDriver in a multi-threaded Rack environment. The solution is production-ready, well-tested, and maintains backward compatibility while eliminating the "stream closed in another thread" errors.
