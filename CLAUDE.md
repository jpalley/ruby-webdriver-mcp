# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a containerized Ruby application that provides a Model Context Protocol (MCP) server for controlling Selenium WebDriver from Large Language Models. It enables LLMs to interact with web browsers through a standardized MCP interface over HTTP.

**Key Technologies:**
- Ruby 3.0+
- FastMCP (Ruby MCP implementation)
- Selenium WebDriver 4.x
- Rack web server (via rackup)
- Docker containerization

## DEVELOPMENT RULES
- ALWAYS use TDD/BDD practices with RSpec
- Follow Ruby style guides (RuboCop configured)
- Write clear, descriptive commit messages
- Ensure thread safety in session management
- Document new tools and configuration options
- Write clean code.  Review existing code to see if it should be cleaned up.

## Development Commands

### Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test types
bundle exec rspec spec/unit/                    # Unit tests only
bundle exec rspec spec/integration_driver_only/ # Integration tests (require Selenium)
bundle exec rspec spec/mcp_integration/         # MCP integration tests

# Run a single test file
bundle exec rspec spec/unit/session_manager_spec.rb

# Run specific test by line number
bundle exec rspec spec/unit/session_manager_spec.rb:42
```

### Code Quality

```bash
# Run RuboCop linter
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -A

# Run both tests and linter (default rake task)
bundle exec rake
```

### Running the Server

```bash
# Docker (recommended)
docker-compose -f docker-compose.production.yml up

# Or build and run manually
docker build -t selenium-mcp-server .
docker run -p 4443:4443 -e SELENIUM_URL=http://selenium:4444/wd/hub selenium-mcp-server

# Local development (requires Selenium running separately)
SELENIUM_URL=http://localhost:4444/wd/hub bundle exec rackup -p 4443
```

## Architecture

### Core Components

1. **SessionManager** (`lib/selenium_webdriver_mcp/session_manager.rb`)
   - Thread-safe singleton managing multiple concurrent browser sessions
   - Each session has its own DriverManager and element cache
   - Critical for multi-client support (multiple LLMs using same server)
   - Uses Mutex for synchronization

2. **DriverManager** (`lib/selenium_webdriver_mcp/driver_manager.rb`)
   - Manages a single Selenium WebDriver instance
   - Handles element caching with auto-generated IDs (`element_0`, `element_1`, etc.)
   - Provides high-level browser operations (navigate, find, click, etc.)
   - Lazy-starts browser on first use

3. **Server** (`lib/selenium_webdriver_mcp/server.rb`)
   - FastMCP server implementation
   - Registers all tools and resources
   - Can run standalone or as Rack middleware
   - Uses HTTP/SSE transport

4. **Configuration** (`lib/selenium_webdriver_mcp/configuration.rb`)
   - Configurable via `SeleniumWebdriverMcp.configure` block
   - Environment variable defaults (SELENIUM_URL, etc.)
   - Builds browser-specific options (Chrome/Firefox/Edge)

### Tool Architecture

All MCP tools inherit from `FastMcp::Tool` and follow this pattern:

```ruby
class ToolName < FastMcp::Tool
  description "What the tool does"

  arguments do
    required(:session_id).filled(:string).description("Session ID")
    required(:param).filled(:type).description("Parameter description")
  end

  def call(session_id:, param:)
    driver_manager = SessionManager.instance.get_driver_manager(session_id)
    driver_manager.method_name(param)
  end
end
```

**Important:** ALL tools (except create_session, destroy_session, list_sessions) require a `session_id` parameter. The session must be created first using `create_session` tool.

### Session Management Flow

```
LLM Client
  → create_session (returns session_id)
  → navigate(session_id, url)
  → find_element(session_id, strategy, value) → returns element_id
  → click_element(session_id, element_id)
  → destroy_session(session_id)
```

Element IDs are session-scoped and cached in the DriverManager. They become stale when the page changes, requiring new find operations.

### Docker Deployment

- **Dockerfile**: Production-ready container image
- **docker-compose.production.yml**: Complete setup with MCP server and Selenium
- **config.ru**: Rack application entry point with health check
- **Environment Variables**: Configure Selenium URL, browser type, port, etc.

## Key Implementation Details

### Thread Safety

**Critical: This application is designed for multi-threaded environments (WEBrick, Puma, etc.)**

The threading model has been carefully architected to prevent "stream closed in another thread" errors:

1. **SessionManager Thread Safety**
   - Uses `Mutex` to synchronize session operations (create, destroy, list)
   - Each session has isolated state (driver, element cache)
   - Element IDs are prefixed and scoped per session

2. **DriverManager Thread Safety**
   - Uses custom `ThreadSafeHttpClient` that wraps all HTTP requests in a mutex
   - Prevents concurrent access to Selenium WebDriver's Net::HTTP connection
   - Each DriverManager has its own `@driver_mutex` for additional protection
   - Element cache operations are mutex-protected

3. **Threading Architecture**
   - WEBrick spawns a NEW thread for each HTTP request
   - MCP requests (create_session, navigate, etc.) may execute in different threads
   - Sessions persist across requests and can be accessed by multiple threads
   - WebDriver instances use thread-safe HTTP client to prevent connection conflicts

4. **Why This Matters**
   - Selenium WebDriver's default Net::HTTP client is NOT thread-safe
   - Without protection, Thread A and Thread B sharing a driver causes:
     - "stream closed in another thread" errors
     - Race conditions in HTTP socket operations
   - Our ThreadSafeHttpClient serializes HTTP requests while maintaining connection reuse

### Element Caching

Elements are cached with auto-incremented IDs:
- `element_0`, `element_1`, etc.
- Cache persists for session lifetime
- Elements can become stale (page navigation, DOM changes)
- Cache is cleared when session is destroyed

### Browser Configuration

Default configuration assumes devcontainer setup:
- Selenium at `http://selenium:4444/wd/hub`
- Chrome browser in headless mode
- Window size 1400x1400
- Common Chrome args: `--no-sandbox`, `--disable-dev-shm-usage`

### Localhost URL Rewriting

For containerized environments, set `REWRITE_LOCALHOST_TO` to rewrite localhost URLs:

```bash
export REWRITE_LOCALHOST_TO=app
```

This rewrites `http://localhost:3000` → `http://app:3000` in the navigate tool.
Essential for Docker setups where browser and app are in different containers.
See `LOCALHOST_REWRITE.md` for details.

### Error Handling

Custom errors raise `SeleniumWebdriverMcp::Error`. Common error scenarios:
- Session not found (invalid session_id)
- Element not in cache (invalid element_id)
- Stale element reference (page changed after find)
- Selenium WebDriver errors (element not found, timeout, etc.)

## Testing Notes

### Test Categories

1. **Unit Tests** (`spec/unit/`): No Selenium required, test Ruby logic
2. **Integration Tests** (`spec/integration_driver_only/`): Require Selenium, test DriverManager
3. **MCP Integration Tests** (`spec/mcp_integration/`): Test full MCP tool flow
4. **Thread Safety Tests** (`spec/integration_driver_only/thread_safety_spec.rb`): Test multi-threaded concurrent access

### Test Helpers

- `spec/support/test_html_server.rb`: Serves test HTML for browser tests
- `spec/support/mcp_client_helper.rb`: Helper for MCP client simulation
- `spec/spec_helper.rb`: RSpec configuration

### Running Integration Tests

Integration tests require a Selenium server running:

```bash
# In devcontainer with docker-compose
docker-compose up selenium

# Or standalone
docker run -d -p 4444:4444 -p 7900:7900 --shm-size="2g" selenium/standalone-chrome:latest
```

### Testing Thread Safety

Thread safety tests verify that multiple threads can safely access sessions concurrently:

```bash
# Run thread safety tests
bundle exec rspec spec/integration_driver_only/thread_safety_spec.rb

# Run with verbose output to see thread IDs
bundle exec rspec spec/integration_driver_only/thread_safety_spec.rb --format documentation
```

These tests simulate real-world scenarios:
- Multiple threads operating on the same session
- Session created in one thread, used in another
- Rapid concurrent element finding operations
- Multiple sessions created in parallel

## Common Patterns

### Adding a New Tool

1. Create file in `lib/selenium_webdriver_mcp/tools/`
2. Inherit from `FastMcp::Tool`
3. Define description and arguments with validation
4. Implement `call` method using SessionManager
5. Register in `Server#register_tools`
6. Add integration test in `spec/mcp_integration/`

### Adding Configuration Options

1. Add attr_accessor to Configuration class
2. Set default in Configuration#initialize
3. Document in README.md configuration section
4. Update generator template if relevant

### Session Lifecycle Management

Sessions auto-expire after 1 hour of inactivity. For long-running operations:
- Update `last_accessed` timestamp on each tool call (automatic)
- Consider adjusting timeout in SessionManager
- Always destroy sessions when done to free resources

## Security Considerations

This gem provides programmatic browser control. Be cautious:
- Only expose MCP server to trusted LLM clients
- Validate URLs before navigation (prevent SSRF)
- Review JavaScript in `execute_script` calls
- Run in isolated/sandboxed environments
- Consider implementing authentication for production use
